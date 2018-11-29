#!/usr/bin/python2

import sys
import telnetlib as tn
import json
#import pprint
import argparse

parser = argparse.ArgumentParser(
    description="Generate assembly source for vector table")
parser.add_argument('host',
    help='Qemu QMP Telnet server hostname')
parser.add_argument('port', type=int,
    help='Qemu QMP Telnet server port')
parser.add_argument('chardevs', nargs="+",
    help='chardev labels to lookup paths for')
args = parser.parse_args()

cl = tn.Telnet(args.host, args.port)

reply = cl.read_until("\r\n")

cl.write('{"execute": "qmp_capabilities"}')
reply = cl.read_until("\r\n")

cl.write('{"execute": "query-chardev"}')
reply = cl.read_until("\r\n")

reply_json = json.loads(reply)
cdevs = reply_json[u"return"]

fnames = {}
for cdev in cdevs:
        fnames[cdev[u"label"]] = cdev[u"filename"]
#pprint.pprint(fnames)

for label in args.chardevs:
        fname = fnames[label]
        fname = fname.replace(u"pty:", u"")
        print(fname),
