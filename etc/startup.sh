#!/bin/bash

/opt/td-agent-bit/bin/td-agent-bit -c /etc/td-agent-bit/td-agent-bit.conf &&
falco-driver-loader && falco

# * Running falco-driver-loader with: driver=module, compile=yes, download=yes
# 	echo ""
# 	echo "Usage:"
# 	echo "  falco-driver-loader [driver] [options]"
# 	echo ""
# 	echo "Available drivers:"
# 	echo "  module        kernel module (default)"
# 	echo "  bpf           eBPF probe"
# 	echo ""
# 	echo "Options:"
# 	echo "  --help         show brief help"
# 	echo "  --compile      try to compile the driver locally"
# 	echo "  --download     try to download a prebuilt driver"
# 	echo "  --source-only  skip execution and allow sourcing in another script"
