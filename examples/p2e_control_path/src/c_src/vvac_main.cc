#include "stdio.h"
#include <cstring>
#include <math.h>
#include <iostream>
#include <string>

#include <vector>
#include <memory>
#include <thread>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/msg.h>
#include <mutex>

#include "ICtb.h"
#include "expFun.h"
#include "stub.h"
//#include "comm_defs.h"
using namespace vvac;

#define _CLEAR  "\033[0m"
#define _RED    "\033[31m"
#define _GREEN  "\033[32m"
#define _BLUE   "\033[34m"
#define _YELLOW "\033[33m"
#define _PURPLE "\033[35m"

#define EXPECT(x,value,str) if (x == value) \
            printf(_BLUE "%s == %d,\texpect %d,\tPASS\n" _CLEAR, str, x, value); \
            else printf(_RED "%s == %d,\texpect %d,\tFAILED\n" _CLEAR, str, x, value) 


static int dut_notice_value = 0;
static svScope scope_waitNCycle;

//#########################################
//    DPI-C with DUT
//#########################################
//export 
// export-dpic
extern "C" void func_get_rtl_value(uint32_t* h2sdat_1, uint32_t* h2sdata_2);

//import 
extern "C" void dut_notice(uint32_t *iVec1)
{
    printf(_YELLOW "%s :iVec1[0]: %x \n" _CLEAR, __func__,*(iVec1 + 0));    
    dut_notice_value = *(iVec1 + 0);

} 

extern "C" uint32_t func_add(uint32_t *i0, uint32_t *i1)
{
    std::cout << _GREEN << "i0: " << i0 << " i1: " << i1 << _CLEAR << std::endl;
    return *i0 + *i1;
}

extern "C" void func_touch(uint32_t *o0)
{
    std::cout << _GREEN << "o0: " << o0 << _CLEAR << std::endl;
    printf(_YELLOW "%s : s2h_data_out0 : %d \n" _CLEAR, __func__,25);  
    *o0 = 25;
    printf(_BLUE "\texpect %d,\tPASS\n" _CLEAR, *o0);
    std::cout << _GREEN << "func run finish " << _CLEAR << std::endl;
}

extern "C" uint32_t func_rec(void)
{
    std::cout << _GREEN << "func_rec called, return 0x5AA5" << _CLEAR << std::endl;
    return 0x5aa5;
}


//#########################################
//     Run/Stop for simulation
//#########################################
//extern "C" void waitNCycles(uint32_t n);
//void waitNCycles_wrapper(uint32_t *cycle, uint32_t n, svScope scope ) {
//    //printf(_PURPLE "%s now %d cycles; to run %x cycles , scope_id: %x\n" _CLEAR, __func__, *cycle, n, scope);
//    svSetScope(scope);
//    waitNCycles(n);
//    *cycle += n;
//}

//#########################################
//     Test Main 
//#########################################
void test_dpic()
{
//    vdbg_exec("design ../../vcom");
//    vdbg_exec("hw_server .");
//    vdbg_exec("download");
    vvac::ICtbMgr *ctb_ = vvac::CtbBuilder::create();
    auto ret = ctb_->init("P0","/public/pingh/for_lauraw/vvac_v2.si/TestCase/vdbg_vvac_import_single_touch_Sout_v2//vvac.dir",
                               "/public/pingh/for_lauraw/vvac_v2.si/TestCase/vdbg_vvac_import_single_touch_Sout_v2/" );
    if (ret) {
        //svSetScope(svGetScopeFromName("vvac_top"));

        uint32_t rtl_point, rtl_cnt;

        std::cout << _YELLOW << "===TEST START===" << _CLEAR << std::endl;
        while(dut_notice_value == 0) { 
            sleep(1);
        }
        std::cout << _YELLOW << "===TEST FINISHED===" << _CLEAR << std::endl;

        ctb_->quit();
        FILE *fp_done = NULL;
        fp_done = fopen("/public/pingh/for_lauraw/vvac_v2.si/TestCase/vdbg_vvac_import_single_touch_Sout_v2//vcom_sim/c_code_done.txt", "w+");
        std::cout << _YELLOW << "===NOTICE VCS DONE ===" << _CLEAR << std::endl;
        fclose(fp_done);
    } else {
        std::cout << "CTB init failed!" << std::endl;
    }
}


int main()
{
    setenv("VMRI_LOG_LEVEL", "0", 1);
    setenv("VVAC_LOG_LEVEL", "0", 1);
    setenv("RBMGR_LOG_LEVEL", "0", 1);
    setenv("RBMGR_DUMP_DATA", "1", 1);
    char *env_vcom_sim = getenv("VCOM_TEST_DIP");
    if (env_vcom_sim != NULL)  {
        setenv("VMRI_WORK_MODE", "4", 1);
        setenv("VVAC_WORK_MODE", "1", 1);
        std::cout << "========= Run For Simulation ==========" << std::endl;
    } else {
        setenv("VMRI_WORK_MODE", "3", 1);
        setenv("VVAC_WORK_MODE", "0", 1);
        std::cout << "========= Run For Onboard Test ==========" << std::endl;
    }
    setenv("RTL_DBG_SIZE", "128", 1);
    test_dpic();
    return 0;
}

