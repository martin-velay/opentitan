// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class ac_range_check_base_vseq extends cip_base_vseq #(
    .RAL_T               (ac_range_check_reg_block),
    .CFG_T               (ac_range_check_env_cfg),
    .COV_T               (ac_range_check_env_cov),
    .VIRTUAL_SEQUENCER_T (ac_range_check_virtual_sequencer)
  );
  `uvm_object_utils(ac_range_check_base_vseq)

  // Various knobs to enable certain routines
  bit do_ac_range_check_init = 1'b1;

  // Randomized variables
  rand tl_main_vars_t  tl_main_vars;
  rand bit [TL_DW-1:0] range_base[NUM_RANGES];  // Granularity is 32-bit words, 2-LSBs are ignored
  rand bit [TL_DW-1:0] range_limit[NUM_RANGES]; // Granularity is 32-bit words, 2-LSBs are ignored
  rand range_perm_t    range_perm[NUM_RANGES];
  rand racl_policy_t   range_racl_policy[NUM_RANGES];

  // Constraints
  extern constraint tl_main_vars_c;

  // Standard SV/UVM methods
  extern function new(string name="");

  // Class specific methods
  extern task dut_init(string reset_kind = "HARD");
  extern task ac_range_check_init();
  extern task cfg_range_base();
  extern task cfg_range_limit();
  extern task cfg_range_perm();
  extern task cfg_range_racl_policy();
  extern task send_single_tl_unfilt_tr(tl_main_vars_t main_vars);
endclass : ac_range_check_base_vseq


// Keep the TL transactions randomized by default, this can be overridden easily by derived
// sequences if needed as declared as soft constraints.
constraint ac_range_check_base_vseq::tl_main_vars_c {
  soft tl_main_vars.rand_write == 1;
  soft tl_main_vars.rand_addr  == 1;
  soft tl_main_vars.rand_mask  == 1;
  soft tl_main_vars.rand_data  == 1;
}

function ac_range_check_base_vseq::new(string name="");
  super.new(name);
endfunction : new

task ac_range_check_base_vseq::dut_init(string reset_kind = "HARD");
  super.dut_init();
  if (do_ac_range_check_init) begin
    ac_range_check_init();
  end
endtask : dut_init

task ac_range_check_base_vseq::ac_range_check_init();
  cfg_range_base();
  cfg_range_limit();
  cfg_range_perm();
  cfg_range_racl_policy();
endtask : ac_range_check_init

task ac_range_check_base_vseq::cfg_range_base();
  foreach (range_base[i]) begin
    ral.range_base[i].set(range_base[i]);
    csr_update(.csr(ral.range_base[i]));
  end
endtask : cfg_range_base

task ac_range_check_base_vseq::cfg_range_limit();
  foreach (range_limit[i]) begin
    ral.range_limit[i].set(range_limit[i]);
    csr_update(.csr(ral.range_limit[i]));
  end
endtask : cfg_range_limit

task ac_range_check_base_vseq::cfg_range_perm();
  foreach (range_perm[i]) begin
    ral.range_perm[i].set({
      prim_mubi_pkg::mubi4_bool_to_mubi(range_perm[i].log_denied_access),
      prim_mubi_pkg::mubi4_bool_to_mubi(range_perm[i].execute_access   ),
      prim_mubi_pkg::mubi4_bool_to_mubi(range_perm[i].write_access     ),
      prim_mubi_pkg::mubi4_bool_to_mubi(range_perm[i].read_access      ),
      prim_mubi_pkg::mubi4_bool_to_mubi(range_perm[i].enable           )
    });
    csr_update(.csr(ral.range_perm[i]));
  end
endtask : cfg_range_perm

task ac_range_check_base_vseq::cfg_range_racl_policy();
  foreach (range_racl_policy[i]) begin
    ral.range_racl_policy_shadowed[i].set(range_racl_policy[i]);
    // Shodowed register: the 2 writes are automatcally managed by the csr_utils_pkg
    csr_update(.csr(ral.range_racl_policy_shadowed[i]));
  end
endtask : cfg_range_racl_policy

task ac_range_check_base_vseq::send_single_tl_unfilt_tr(tl_main_vars_t main_vars);
  tl_host_single_seq seq;
  `uvm_create_on(seq, p_sequencer.tl_unfilt_sqr)
  `DV_CHECK_RANDOMIZE_WITH_FATAL( seq,
                                  (!main_vars.rand_write) -> (write == main_vars.write);
                                  (!main_vars.rand_addr ) -> (addr  == main_vars.addr);
                                  (!main_vars.rand_mask ) -> (mask  == main_vars.mask);
                                  (!main_vars.rand_data ) -> (data  == main_vars.data);)

  csr_utils_pkg::increment_outstanding_access();
  `DV_SPINWAIT(`uvm_send(seq), "Timed out when sending fetch request")
  csr_utils_pkg::decrement_outstanding_access();

  // At this point, the TL transaction should have completed and the response will be in seq.rsp.
  // The fetch was successful if d_error is false.
  `DV_CHECK(!seq.rsp.d_error, "Single TL unfiltered transaction failed")
endtask : send_single_tl_unfilt_tr
