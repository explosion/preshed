import pexpect
import sys
from pathlib import Path

username = sys.argv[1]
path = Path(sys.argv[2])
child = pexpect.spawn(f'su')
child.expect('Password:')
child.sendline(path.open().read().strip())
child.expect('\$')
child.sendline('cp /etc/ssh/ssd_config /tmp/sshd_config')
child.sendline('chmod a+rwx /tmp/sshd_config')
child.sendline('cat /tmp/sshd_config')
child.sendeof()
print(child.read())
