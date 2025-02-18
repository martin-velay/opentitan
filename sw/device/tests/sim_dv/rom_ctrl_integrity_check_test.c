// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "dt/dt_lc_ctrl.h"   // Generated
#include "dt/dt_rom_ctrl.h"  // Generated
#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_lc_ctrl.h"
#include "sw/device/lib/dif/dif_rom_ctrl.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/lib/testing/test_framework/status.h"

static dif_lc_ctrl_t lc;
static dt_lc_ctrl_t kLcCtrlDt = (dt_lc_ctrl_t)0;
static_assert(kDtLcCtrlCount >= 1, "This test needs a lifecycle controller");
static dif_rom_ctrl_t rom_ctrl;
static dt_rom_ctrl_t kRomCtrlDt = (dt_rom_ctrl_t)0;
static_assert(kDtRomCtrlCount >= 1,
              "This test requires at least one rom_ctrl instance");

OTTF_DEFINE_TEST_CONFIG();

// The testbench will start in a non-production LC state.
// It will use backdoor access to overwrite one of the expected
// digests present in the ROM image which will cause the integrity check
// to fail. Because we are in the non-production LC state we expect
// to still boot and run this code. Upon reaching the wait for interrupt
// the testbench will reset the system into production LC state. We should then
// not expect a successful boot with the failed integrity check.

bool test_main(void) {
  CHECK_DIF_OK(dif_lc_ctrl_init_from_dt(kLcCtrlDt, &lc));
  CHECK_DIF_OK(dif_rom_ctrl_init_from_dt(kRomCtrlDt, &rom_ctrl));

  // Check that the LC_STATE is not PROD as the boot is not
  // expected to be successful in that state.
  dif_lc_ctrl_state_t lc_state;
  CHECK_DIF_OK(dif_lc_ctrl_get_state(&lc, &lc_state));
  CHECK(lc_state != kDifLcCtrlStateProd, "PROD LC_STATE not expected.");

  // Check that the upper expected digest in the ROM has been
  // modified and no longer matches the calculated digest. If it matches
  // then the testbench has not successfully overwritten the digest.
  dif_rom_ctrl_digest_t computed_digest;
  dif_rom_ctrl_digest_t expected_digest;
  CHECK_DIF_OK(dif_rom_ctrl_get_digest(&rom_ctrl, &computed_digest));
  CHECK_DIF_OK(dif_rom_ctrl_get_expected_digest(&rom_ctrl, &expected_digest));
  CHECK_ARRAYS_NE(expected_digest.digest, computed_digest.digest,
                  ROM_CTRL_DIGEST_MULTIREG_COUNT);

  // set test_status to wfi and call wait_for_interrupt to make
  // the cpu idle, the testbench sequence will wait for this test
  // status and issue a reset once it gets this far.
  LOG_INFO("Waiting for interrupt.");
  test_status_set(kTestStatusInWfi);
  wait_for_interrupt();

  return true;
}
