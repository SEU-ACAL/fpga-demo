#include "stdio.h"
#include "svdpi.h"
#include "iostream"


#define _CLEAR  "\033[0m"
#define _RED    "\033[31m"
#define _GREEN  "\033[32m"
#define _BLUE   "\033[34m"
#define _YELLOW "\033[33m"
#define _PURPLE "\033[35m"
///////////////////////////////
//     DPIC-func  use _PURPLE 
//     TEST-code  use _BLUE
//     
//     ERROR:  use  _RED
//     
///////////////////////////////
static svScope scope_func_add;
static svScope scope_func_touch;
static svScope scope_func_rec;
static svScope scope_func_call;
static svScope scope_waitNCycle;
static svScope scope_dut_top;
static svScope scope_reset_rtl;
static svScope scope_get_rtl_value;
static bool  scope_flag = false ;

#define EXPECT(x,value,str) if (x == value) \
            printf(_BLUE "%s == %d,\texpect %d,\tPASS\n" _CLEAR, str, x, value); \
            else printf(_RED "%s == %d,\texpect %d,\tFAILED\n" _CLEAR, str, x, value) 
//#########################################
//    DPI-C with DUT
//#########################################

extern "C" void waitNCycles(uint32_t n);
extern "C" void func_reset_rtl(uint32_t reset);
extern "C" void func_get_rtl_value(uint32_t* o1, uint32_t* o2);
extern "C" void task_reset_rtl(uint32_t reset);
extern "C" void task_get_rtl_value(uint32_t* o1, uint32_t* o2);
extern "C" void exp_h2s0_s2h32(uint32_t* o1, uint32_t* i1);
extern "C" void exp_h2s64_s2h0(uint32_t* o1, uint32_t* ivec);

extern "C" uint32_t func_add(uint32_t *i0, uint32_t *i1)
{
    //printf("i0: %d, i1: %d\n", *i0, *i1);
    return *i0 + *i1;
}

extern "C" void func_touch(uint32_t *o0)
{
    std::cout << _GREEN << "o0: " << o0 << _CLEAR << std::endl;
    printf(_YELLOW "%s : s2h_data_out0 : %d \n" _CLEAR, __func__,25);  
    *o0 = 25;
    printf(_BLUE "\texpect %d,\tPASS\n" _CLEAR, *o0);
}

extern "C" uint32_t func_rec()
{
    return 0x55aa;
}

extern "C" void func_call()
{
    printf("%s called\n", __func__);
}

extern "C" void imp_h2s64_s2h32(uint32_t* i0, uint32_t* o0)
{
    svScope scope_caller = svGetScope();
    if (scope_flag == true) {
        if (scope_caller == scope_func_add){
            *o0 = func_add(i0, i0 + 1);
            return;
        }
        printf(_PURPLE "%s : miss scope\n" _CLEAR, __func__);
    }
}

extern "C" void imp_h2s32_s2h0(uint32_t* i0)
{
    svScope scope_caller = svGetScope();
    if (scope_flag == true) {
        if (scope_caller == scope_func_touch){
            func_touch(i0);
            return;
        }
        printf(_PURPLE "%s : miss scope\n" _CLEAR, __func__);
    }
}

extern "C" void imp_h2s0_s2h32(uint32_t* o0)
{
    svScope scope_caller = svGetScope();
    if (scope_flag == true) {
        if (scope_caller == scope_func_rec){
            *o0 = func_rec();
            return;
        }
        printf(_PURPLE "%s : miss scope\n" _CLEAR, __func__);
    }
}

extern "C" void imp_h2s0_s2h0()
{
    svScope scope_caller = svGetScope();
    if (scope_flag == true) {
        if (scope_caller == scope_func_call){
            func_call();
            return;
        }
        printf(_PURPLE "%s : miss scope\n" _CLEAR, __func__);
    }
}
//#########################################
//     Wrapper DPI-C API with it's svScope
//#########################################

void waitNCycles_wrapper(uint32_t *cycle, uint32_t n, svScope scope ) {
    printf(_PURPLE "%s run %d cycles\n" _CLEAR, __func__, n);
    svSetScope(scope);
    waitNCycles(n);
    *cycle += n;
}

void reset_rtl_wrapper(uint32_t reset, svScope scope){
    printf(_PURPLE "%s : %x\n" _CLEAR, __func__ , reset);
    svSetScope(scope);
#ifdef VSYN_SIM
    uint32_t tmp = 0;
    exp_h2s0_s2h32(&reset, &tmp);
#else
    #ifdef CASE_USE_TASK
    task_reset_rtl(reset);
    #else  //CASE_USE_TASK
    func_reset_rtl(reset);
    #endif //CASE_USE_FUNC     
#endif
}

void get_rtl_value_wrapper(uint32_t *o1, uint32_t *o2, svScope scope){
    svSetScope(scope);
#ifdef VSYN_SIM
    uint32_t arr[2] = {0};
    uint32_t tmp = 0;
    exp_h2s64_s2h0(&tmp, arr);
    *o1 = arr[0];
    *o2 = arr[1];
#else
    #ifdef CASE_USE_TASK
    task_get_rtl_value(o1, o2);
    #else  //CASE_USE_TASK
    func_get_rtl_value(o1, o2);
    #endif //CASE_USE_FUNC     
   #endif
}

//#########################################
//     Test Main 
//#########################################
extern "C" void init_ctb() {
    printf(_PURPLE "simulation start\n" _CLEAR);
    // get scope here 
    scope_waitNCycle = svGetScopeFromName("vcs_tb");
    scope_dut_top = svGetScopeFromName("vcs_tb.dut_top");
#ifndef VSYN_SIM
    scope_reset_rtl = scope_dut_top;
    scope_get_rtl_value = scope_dut_top;
    scope_func_add = scope_dut_top;
    scope_func_touch = scope_dut_top;
    scope_func_rec = scope_dut_top;
    scope_func_call = scope_dut_top;
#else 
    scope_reset_rtl = svGetScopeFromName("vcs_tb.dut_top._L30_exFunPort");
    scope_get_rtl_value = svGetScopeFromName("vcs_tb.dut_top._L34_exFunPort");
    scope_func_add = svGetScopeFromName("vcs_tb.dut_top._L105_imFunPort");
    scope_func_touch = svGetScopeFromName("vcs_tb.dut_top._L76_imFunPort");
    scope_func_rec = svGetScopeFromName("vcs_tb.dut_top._L98_imFunPort");
    scope_func_call = svGetScopeFromName("vcs_tb.dut_top._L109_imFunPort");
#endif //VSYN_SIM

    scope_flag = true;

    uint32_t reset  = 1;
    uint32_t clk_cycle = 0;
    uint32_t rtl_s2h_out1 = 0;
    uint32_t rtl_q_out = 0;
    uint32_t q = 0;
    
    // Step1  Do DUT Reset // 
    {
        reset_rtl_wrapper (1, scope_reset_rtl);
        waitNCycles_wrapper(&clk_cycle, 10, scope_waitNCycle);
        reset_rtl_wrapper(0, scope_reset_rtl);
        get_rtl_value_wrapper(&rtl_s2h_out1, &rtl_q_out, scope_get_rtl_value);

        printf(_PURPLE "%s Step1 : After DUT Reset: s2h_out1 %x, q_out %x\n" _CLEAR,
               __func__, rtl_s2h_out1, rtl_q_out);
    }
    
    // Step2  let value_display print value // 
    {
        waitNCycles_wrapper(&clk_cycle, 1, scope_waitNCycle);
        get_rtl_value_wrapper(&rtl_s2h_out1, &rtl_q_out, scope_get_rtl_value);

        // expect
        EXPECT(rtl_s2h_out1,  2023, "rtl_s2h_out1");
        EXPECT(rtl_q_out,     1, "   rtl_q_out");
        func_touch(&q);
        waitNCycles_wrapper(&clk_cycle, 5, scope_waitNCycle);
        get_rtl_value_wrapper(&rtl_s2h_out1, &rtl_q_out, scope_get_rtl_value);

        EXPECT(rtl_s2h_out1, 2023, "rtl_s2h_out1");
        EXPECT(rtl_q_out,     6, "   rtl_q_out");

//        waitNCycles_wrapper(&clk_cycle, 250, scope_waitNCycle);
//        get_rtl_value_wrapper(&rtl_s2h_out1, &rtl_q_out, scope_get_rtl_value);

//        EXPECT(rtl_s2h_out1, 2023, "rtl_s2h_out1");
//        EXPECT(rtl_q_out,     0, "   rtl_q_out");
    }
    
    // Step3  Done Test // 
    {
        waitNCycles_wrapper(&clk_cycle, 100, scope_waitNCycle);
        printf(_PURPLE "%s DONE Test after   %d   cycles: \n " _CLEAR,
               __func__ , clk_cycle);
    }
}
