import pexpect
import sys
import time
from pathlib import Path

username = sys.argv[1]
path = Path(sys.argv[2])
child = pexpect.spawn(f'su - {username}')
child.expect('Password:')
child.sendline(path.open().read().strip())
child.expect('\$')
child.sendline('sudo su')
child.sendline(path.open().read().strip())
#child.sendline('journalctl -u sshd -n 100 --no-tail')
#child.sendline('sed -i "s/ListenAddress 0.0.0.0/#ListenAddress 0.0.0.0/" /etc/ssh/sshd_config')
child.sendline('ps -ef | grep sshd')
child.sendline('/usr/sbin/sshd -D -d -p 3002 -o "ListenAddress 0.0.0.0"')
time.sleep(60)
child.sendeof()
#child.sendline('cp /etc/ssh/sshd_config /tmp/sshd_config')
#child.sendline('chmod a+rwx /tmp/sshd_config')
child.sendeof()
child.sendeof()
print(child.read().decode("utf8"))
