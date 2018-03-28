#=========================================================================
# configure.mk
#=========================================================================
# This file will be included inside the Makefile in the build directory

#-------------------------------------------------------------------------
# Step Description -- dc-synthesis
#-------------------------------------------------------------------------
# This step runs synthesis using Synopsys DC

#-------------------------------------------------------------------------
# ASCII art
#-------------------------------------------------------------------------

define ascii.dc-synthesis
	@echo -e $(echo_green)
	@echo '#################################################################################'
	@echo '#                      _____  __  __  _   _  _______  _   _                     #'
	@echo '#                     / ____||  \/  || \ | ||__   __|| | | |                    #'
	@echo '#                    | (___   \    / |  \| |   | |   | |_| |                    #'
	@echo '#                     \___ \   |  |  | . ` |   | |   |  _  |                    #'
	@echo '#                     ____) |  |  |  | |\  |   | |   | | | |                    #'
	@echo '#                    |_____/   |__|  |_| \_|   |_|   |_| |_|                    #'
	@echo '#                                                                               #'
	@echo '#################################################################################'
	@echo -e $(echo_nocolor)
endef

#-------------------------------------------------------------------------
# Alias -- short name for this step
#-------------------------------------------------------------------------

abbr.dc-synthesis = synth

#-------------------------------------------------------------------------
# Variables
#-------------------------------------------------------------------------

# Pass

#-------------------------------------------------------------------------
# Build
#-------------------------------------------------------------------------

# Verilog sources (do not include test harness!)

vsrcs = $(relative_base_dir)/rtl-handoff/$(vsrc)

# Specify toplevel verilog module

toplevel = $(vmname)

# The ALIB directory is where DC caches analyzed libraries (.alib files).
# Normally, we use: $(cells_dir)/alib
#
# If DC sees a .db that does not have an associated .alib it will
# automatically create one, but the problem is students do not have write
# permission to the above directory. This is not usually a problem when
# students just use standard cells, but if a student is trying to use
# SRAMs, then they will be using new .db files that DC has not seen yet.
# The only problem is, that analyzing the standard cell library does take
# a little while (minute or two) which is annoying on every build.
#
# So the current solution is if there are no SRAMs then we just use the
# above global ALIB directory. If there are SRAMs we use an ALIB
# directory that is in parallel with the build directories so we can at
# least amortize the analyze time across builds.

ifeq ($(strip $(srams)),)
  alib_dir=$(adk_dir)/stdcells.alib
else
  alib_dir=alib
endif

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

dc_exec         = dc_shell-xg-t -64bit -topographical_mode

dc_tcl          = $(flow_dir.dc-synthesis)/rm_dc_scripts/dc.tcl
dc_misc_tcl     = $(flow_dir.dc-synthesis)/rm_dc_scripts/find_regs.tcl
makegen_tcl     = make_generated_vars.tcl

constraints_tcl = $(plugins_dir.dc-synthesis)/constraints.tcl

# SAIF variables

ifeq ($(strip $(viname)),)
  viname = NONE
endif

# Derating the clock period for DC
#
# We push timing in DC to provide ICC with a better timing-optimized
# netlist to start out with. To do this, we derate the clock for DC, while
# ICC still works with the clock target defined in the Makefrag.
#
# Use the calculator `bc` to derate the clock:
#
# - "scale" is a bc parameter that determines the total number of decimal
#   digits after the decimal point

#dc_clock_period = 0$(shell echo "scale=4; ${clock_period}*0.9" | bc)
dc_clock_period = $(clock_period)

vars = \
	set VINAME                      "$(viname)";\n \
	set DESIGN_NAME                 "$(toplevel)";\n \
	set STRIP_PATH                  "$(toplevel)";\n \
	set ADDITIONAL_SEARCH_PATH      "$(adk_dir)";\n \
	set TARGET_LIBRARY_FILES        "stdcells.db iocells.db";\n \
	set MW_REFERENCE_LIB_DIRS       "$(adk_dir)/stdcells.mwlib";\n \
	set TECH_FILE                   "$(adk_dir)/rtk-tech.tf";\n \
	set MAP_FILE                    "$(adk_dir)/rtk-tluplus.map";\n \
	set TLUPLUS_MAX_FILE            "$(adk_dir)/rtk-max.tluplus";\n \
	set TLUPLUS_MIN_FILE            "$(adk_dir)/rtk-min.tluplus";\n \
	set ALIB_DIR                    "$(alib_dir)";\n \
	set RTL_SOURCE_FILES            "$(vsrcs)";\n \
	set DCRM_CONSTRAINTS_INPUT_FILE "$(constraints_tcl)";\n \
	set DC_SETUP_DIR                "$(flow_dir.dc-synthesis)/rm_setup";\n \
	set DC_MISC_TCL                 "$(dc_misc_tcl)";\n \
	set REPORTS_DIR                 "$(reports_dir.dc-synthesis)";\n \
	set RESULTS_DIR                 "$(results_dir.dc-synthesis)";\n \
	set CLOCK_PERIOD                "$(dc_clock_period)";\n \
	set CELLS_TCL                   "$(adk_dir)/stdcells.tcl";\n \

#-------------------------------------------------------------------------
# Primary command target
#-------------------------------------------------------------------------
# These are the commands run when executing this step. These commands are
# included into the build Makefile.

define commands.dc-synthesis

# Make build directories

	mkdir -p $(logs_dir.dc-synthesis)
	mkdir -p $(reports_dir.dc-synthesis)
	mkdir -p $(results_dir.dc-synthesis)

# Generate tcl variables from Makefile

	echo -e '$(vars)' > $(makegen_tcl)

# Run the synthesis script

	$(dc_exec) -f $(dc_tcl) \
             -output_log_file $(logs_dir.dc-synthesis)/dc.log

# Clean up

	mv make_generated_vars.tcl $(logs_dir.dc-synthesis)
	mv command.log             $(logs_dir.dc-synthesis)
	mv lc_shell_command.log    $(logs_dir.dc-synthesis)
	mv *_LIB                   $(logs_dir.dc-synthesis)
	mv WORK                    $(logs_dir.dc-synthesis)
	mv force_regs.ucli         $(logs_dir.dc-synthesis)
	mv access.tab              $(logs_dir.dc-synthesis)

# Put handoffs in place

	mkdir -p $(handoff_dir.dc-synthesis)
	(cd $(handoff_dir.dc-synthesis) && \
    ln -sf ../../$(results_dir.dc-synthesis)/* .)

# Grep for errors

	grep --color "^Error" $(logs_dir.dc-synthesis)/dc.log || true
	grep --color -B 3 "*** Presto compilation terminated" \
    $(logs_dir.dc-synthesis)/dc.log || true
	grep --color "unresolved references." \
    $(logs_dir.dc-synthesis)/dc.log || true

endef

#-------------------------------------------------------------------------
# Extra targets
#-------------------------------------------------------------------------
# These are extra useful targets when working with this step. These
# targets are included into the build Makefile.

# Clean

clean-dc-synthesis:
	rm -rf ./$(VPATH)/dc-synthesis
	rm -rf ./$(logs_dir.dc-synthesis)
	rm -rf ./$(reports_dir.dc-synthesis)
	rm -rf ./$(results_dir.dc-synthesis)
	rm -rf ./$(collect_dir.dc-synthesis)
	rm -rf ./$(handoff_dir.dc-synthesis)

clean-synth: clean-dc-synthesis

# Debug

#debug-dc-synthesis:
#debug-synth: debug-dc-synthesis

