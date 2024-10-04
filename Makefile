RTL_FILES = ctl.sv defs.sv memory.sv top.sv

.PHONY: all
all: sim run

sim: ${RTL_FILES}
	iverilog -g2012 -o $@ -s top ${RTL_FILES}

run: sim
	./sim

