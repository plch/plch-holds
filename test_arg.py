import sys
import configparser
from textwrap import dedent

# print('Number of arguments:', len(sys.argv), 'arguments.')
# print('Argument List:', str(sys.argv))

# config = configparser.ConfigParser(allow_no_value=True)
# config.read('config.ini')
# arglist = list([arg.strip(' ') for arg in config['arglist']['args'].split(',')])

# print (arglist)

# possible options / reports
arglist = list(['system-wide', 'ninety-day', 'holds-no-copies'])

def print_arg_error():
    # no args, do testing
    msg = """
    Error: argument not correct or missing.
    Valid arguments below: 
    """
    print(dedent(msg))
    print(*arglist, sep="\n")

try:
    if sys.argv[1] in arglist:
        # found argument in list ...
        if sys.argv[1] == 'system-wide':
            print(sys.argv[1])
            pass
        elif sys.argv[1] == 'ninety-day':
            print(sys.argv[1])
            pass
        elif sys.argv[1] == 'holds-no-copies':
            print(sys.argv[1])
            pass
    else:
        print_arg_error()

except:
   print_arg_error()