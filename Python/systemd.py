#!/usr/bin/python36
##############################################################################
# Tests for 'running' status from systemd for a service specified as the 1st arg.
#
# Version:      Name:           Date:           Comments:
# 0.1           Toby Bigwood    28/01/2019      Initial
#
##############################################################################

# Variables
testname = 'Check Qualys is running under systemd:'

# Modules
import subprocess
import sys

# Test for first argument, if none, don't print IndexError but print ERROR message
try:
    service = sys.argv[1]
except IndexError:
    print ('ERROR: Please specify service name as argument 1')
    sys.exit(1)

# Use subprocess.call as we only care about the RC value (0=Running), anything else is a fail
return_code = subprocess.call(['systemctl', 'status', service], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if return_code != 0:
    if return_code == 3:
       print(testname, 'FAIL', service, 'not running?')
    elif return_code == 4:
       print(testname, 'FAIL', service, 'not found?')
    else:
       print(testname, 'FAIL', service, 'unknown status')
    sys.exit(return_code)
else:
    print(testname, 'PASS')