import pexpect
import sys
from pathlib import Path

username = sys.argv[1]
path = Path(sys.argv[2])
child = pexpect.spawn(f'su - {username}')
child.expect('Password:')
child.sendline(path.open().read().strip())
child.expect('\$')
child.sendline('ls /etc/ssh/')
