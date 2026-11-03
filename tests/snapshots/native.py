"""Run the existing editor checkers in the pinned capture environment."""

import os
import subprocess
from pathlib import Path


CHECKERS = ('scripts/check-highlights.lua', 'scripts/check-semantic-tokens.lua', 'tests/lualine.lua')


def main(root: Path = Path('/repo'), output: Path = Path('/output')) -> int:
    Path(os.environ['HOME']).mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, FLUME_LUALINE_RUNTIME='/opt/tools/lualine')
    with (output / 'native.log').open('w') as log:
        for checker in CHECKERS:
            command = ['nvim', '--headless', '--clean', '-c', f"lua dofile('{checker}')"]
            log.write(f'Check: {checker}\n')
            log.flush()
            result = subprocess.run(command, cwd=root, env=environment,
                                    stdout=log, stderr=subprocess.STDOUT, check=False)
            log.write(f'Exit: {result.returncode}\n')
            log.flush()
            if result.returncode:
                return result.returncode
    print('PASS: native highlights, gopls semantic tokens and installed lualine')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
