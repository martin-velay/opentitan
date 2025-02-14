CAPI=2:
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
name: ${instance_vlnv("lowrisc:dv:ac_range_check_sim:0.1")}
description: "AC_RANGE_CHECK DV sim target"
filesets:
  files_rtl:
    depend:
      - lowrisc:ip:tlul
      - ${instance_vlnv("lowrisc:ip:ac_range_check:0.1")}
    file_type: systemVerilogSource

  files_dv:
    depend:
      - ${instance_vlnv("lowrisc:dv:ac_range_check_test")}
      - ${instance_vlnv("lowrisc:dv:ac_range_check_sva")}
      - ${instance_vlnv("lowrisc:dv:ac_range_check_cov")}
    files:
      - tb/tb.sv
    file_type: systemVerilogSource

targets:
  sim: &sim_target
    toplevel: tb
    filesets:
      - files_rtl
      - files_dv
    default_tool: xcelium

  lint:
    <<: *sim_target
