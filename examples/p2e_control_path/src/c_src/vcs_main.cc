


#include "stdio.h"
#include <cstring>
#include <math.h>
#include <iostream>
#include <string>
#include "svdpi.h"
#include <fstream>

using namespace std;
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
extern "C" void waitNCycles(uint32_t n);
void waitNCycles_wrapper(uint32_t *cycle, uint32_t n, svScope scope ) {
    //printf(_PURPLE "%s now %d cycles; to run %x cycles , scope_id: %x\n" _CLEAR, __func__, *cycle, n, scope);
    svSetScope(scope);
    waitNCycles(n);
    *cycle += n;
}

//#########################################
//     Test Main 
//#########################################
extern "C" void init_ctb() {
    printf(_PURPLE "simulation start\n" _CLEAR);
    // get scope here 
    scope_waitNCycle = svGetScopeFromName("vcs_tb");

    uint32_t clk_cycle = 0;
    // Step1  Do DUT Reset // 
    {

    }
    
    // Step2  Run  // 
    {
         int i = 0;
         while(dut_notice_value == 0) {
            waitNCycles_wrapper(&clk_cycle, 1, scope_waitNCycle);
         }
    }
    
    // Step3  Done Test // 
    {
        printf(_PURPLE "%s DONE Test after   %x   cycles: \n " _CLEAR,
               __func__ , clk_cycle);
    }
}
