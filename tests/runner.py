"""Stage runtime and source, then launch Bats under a fail-closed macOS sandbox.

The staging process is the only host-aware component. No host environment or
repository path is forwarded to the actual test processes.
"""
import os
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
# Resolve host tools before discarding environment; they are COPIED, not symlinked.
TOOLS = {name: shutil.which(name) for name in ("bash", "jq")}
BATS = Path(os.environ.get("BATS_CORE_ROOT", PROJECT / ".test-tools/bats-core")).resolve()
os.environ.clear()
os.environ.update(PATH="/usr/bin:/bin", LANG="C", LC_ALL="C", TZ="UTC")


def checked(*args):
    """Execute only preparation tools; never source or execute production here."""
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def stage_runtime(root):
    """Copy Bash/jq and non-system dylibs, rewriting load paths into TEST_ROOT."""
    runtime = root / "runtime"
    (runtime / "bin").mkdir(parents=True)
    (runtime / "lib").mkdir()
    copied = {}

    def copy_binary(source, destination):
        source = source.resolve(strict=True)
        if destination in copied:
            if copied[destination] != source:
                raise RuntimeError(f"Conflicting runtime library: {destination.name}")
            return
        copied[destination] = source
        shutil.copy(source, destination)
        os.chmod(destination, 0o755)
        lines = checked("/usr/bin/otool", "-L", str(source)).splitlines()[1:]
        dependencies = [line.strip().split(" (compatibility", 1)[0] for line in lines]
        if destination.suffix == ".dylib":
            dependencies = dependencies[1:]  # LC_ID_DYLIB is not a dependency.
        for dep in dependencies:
            if dep.startswith(("/usr/lib/", "/System/Library/")):
                continue
            if dep.startswith("@loader_path/"):
                dep_path = source.parent / dep[len("@loader_path/"):]
            elif dep.startswith("/"):
                dep_path = Path(dep)
            else:
                raise RuntimeError(f"Unsupported runtime load path: {dep}")
            staged = runtime / "lib" / dep_path.name
            copy_binary(dep_path, staged)
            relative = "../lib/" if destination.parent.name == "bin" else ""
            checked("/usr/bin/install_name_tool", "-change", dep,
                    "@loader_path/" + relative + dep_path.name, str(destination))
        if destination.suffix == ".dylib":
            checked("/usr/bin/install_name_tool", "-id", "@loader_path/" + destination.name,
                    str(destination))
        checked("/usr/bin/codesign", "--force", "--sign", "-", str(destination))

    for name, source in TOOLS.items():
        if not source:
            raise RuntimeError(f"Missing host test dependency: {name}")
        copy_binary(Path(source), runtime / "bin" / name)
    return runtime


def main():
    """Scrub paths and environment before Bats; remove only the owned temporary tree."""
    if sys.platform != "darwin":
        raise RuntimeError("This suite requires macOS sandbox-exec; no unsandboxed fallback.")
    if not (BATS / "bin/bats").is_file():
        raise RuntimeError("Bats-core missing. Run tests/bootstrap.bash first.")
    root = Path(tempfile.mkdtemp(prefix="refresh-tests-", dir="/private/tmp")).resolve()
    identity = root.stat().st_ino
    try:
        for name in ("home", "tmp", "cases", "suite"):
            (root / name).mkdir()
        runtime = stage_runtime(root)
        shutil.copytree(PROJECT / "tests", root / "suite/tests")
        shutil.copy2(PROJECT / "refresh_system.sh", root / "suite/refresh_system.sh")
        shutil.copytree(BATS, root / "bats", ignore=shutil.ignore_patterns(".git"))
        # Reject machine-specific home literals in the test subject before executing it.
        source = (root / "suite/refresh_system.sh").read_text()
        if "/Users/" in source or "/home/" in source:
            raise RuntimeError("Production source embeds a real-home candidate; refusing execution.")
        (root / ".isolated-suite").write_text("macOS sandbox required\n")
        env = {
            "TEST_ROOT": str(root), "REFRESH_TEST_ROOT": str(root), "HOME": str(root / "home"),
            "TMPDIR": str(root / "tmp"), "BATS_TMPDIR": str(root / "tmp"),
            "PATH": f"{runtime}/bin:/usr/bin:/bin", "SHELL": str(runtime / "bin/bash"),
            "TEST_BASH": str(runtime / "bin/bash"),
            "LOGNAME": "fixture-home", "USER": "fixture-home", "TERM": "dumb",
            "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8", "TZ": "UTC",
            "REFRESH_TEST_ISOLATED": "1", "BATS_TEST_RETRIES": "0",
        }
        # Root is the working directory: PWD and inherited launch paths cannot expose host HOME.
        sandbox = ["/usr/bin/sandbox-exec", "-D", f"TEST_ROOT={root}",
                   "-f", str(root / "suite/tests/sandbox.sb")]
        checked_env = subprocess.run(sandbox + ["/usr/bin/true"], cwd=root, env=env)
        if checked_env.returncode:
            raise RuntimeError("Cannot activate sandbox; tests were NOT run.")
        version_check = subprocess.run(sandbox + [str(runtime / "bin/bash"),
                                       "--noprofile", "--norc", "-c",
                                       "(( BASH_VERSINFO[0] >= 5 ))"], cwd=root, env=env)
        if version_check.returncode:
            raise RuntimeError("The staged Bash must be version 5 or newer.")
        child = subprocess.Popen(sandbox + [str(runtime / "bin/bash"),
                                 str(root / "bats/bin/bats"), "--tap",
                                 str(root / "suite/tests"), *sys.argv[1:]],
                                 cwd=root, env=env, start_new_session=True)
        try:
            return child.wait(timeout=120)
        finally:
            # Only this launch's process group; never enumerate or match process names.
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait()

    finally:
        # Never trust an empty, replaced, symlinked or relocated teardown target.
        if (root.parent == Path("/private/tmp") and root.name.startswith("refresh-tests-")
                and not root.is_symlink() and root.stat().st_ino == identity):
            shutil.rmtree(root)
        else:
            raise RuntimeError("Unsafe teardown target; refusing removal.")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"Test runner stopped: {error}", file=sys.stderr)
        sys.exit(1)
