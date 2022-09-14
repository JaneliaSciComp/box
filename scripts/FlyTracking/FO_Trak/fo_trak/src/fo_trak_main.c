/*
 * MATLAB Compiler: 4.9 (R2008b)
 * Date: Wed Apr  7 10:58:35 2010
 * Arguments: "-B" "macro_default" "-o" "fo_trak" "-W" "main" "-d"
 * "/groups/flyprojects/home/olympiad/FO_Trak/fo_trak/src" "-T" "link:exe" "-R"
 * "-nojvm" "-N" "-p" "images"
 * "/groups/flyprojects/home/olympiad/FO_Trak/olympiadTrak.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/analysis_olympiad.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/bg_simple.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/candidate_objects.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/dist2.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/get_centroids.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/get_obj_coords.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/load_image.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/main.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/mark_square_object.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/post_main.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/predict_candidate.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/predict_obj_pos.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/process_frame.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/read_params_olympiad.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/set_ROI_to_all.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/track_analysis_params.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/track_obj.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/traj_post_process.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/update_obj_info.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/write_excel.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/filenamesplit.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/isavi.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/issbfmf.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/remove_white_space_extension
 * .m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/sbfmf_read_frame.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/sbfmf_read_header.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/utils/sbfmfreadframe.m" 
 */

#include <stdio.h>
#include "mclmcrrt.h"
#ifdef __cplusplus
extern "C" {
#endif

extern mclComponentData __MCC_fo_trak_component_data;

#ifdef __cplusplus
}
#endif

static HMCRINSTANCE _mcr_inst = NULL;


#ifdef __cplusplus
extern "C" {
#endif

static int mclDefaultPrintHandler(const char *s)
{
  return mclWrite(1 /* stdout */, s, sizeof(char)*strlen(s));
}

#ifdef __cplusplus
} /* End extern "C" block */
#endif

#ifdef __cplusplus
extern "C" {
#endif

static int mclDefaultErrorHandler(const char *s)
{
  int written = 0;
  size_t len = 0;
  len = strlen(s);
  written = mclWrite(2 /* stderr */, s, sizeof(char)*len);
  if (len > 0 && s[ len-1 ] != '\n')
    written += mclWrite(2 /* stderr */, "\n", sizeof(char));
  return written;
}

#ifdef __cplusplus
} /* End extern "C" block */
#endif

/* This symbol is defined in shared libraries. Define it here
 * (to nothing) in case this isn't a shared library. 
 */
#ifndef LIB_fo_trak_C_API 
#define LIB_fo_trak_C_API /* No special import/export declaration */
#endif

LIB_fo_trak_C_API 
bool MW_CALL_CONV fo_trakInitializeWithHandlers(
    mclOutputHandlerFcn error_handler,
    mclOutputHandlerFcn print_handler
)
{
  if (_mcr_inst != NULL)
    return true;
  if (!mclmcrInitialize())
    return false;
  if (!mclInitializeComponentInstanceWithEmbeddedCTF(&_mcr_inst,
                                                     &__MCC_fo_trak_component_data,
                                                     true, NoObjectType,
                                                     ExeTarget, error_handler,
                                                     print_handler, 1288243, (void *)(fo_trakInitializeWithHandlers)))
    return false;
  return true;
}

LIB_fo_trak_C_API 
bool MW_CALL_CONV fo_trakInitialize(void)
{
  return fo_trakInitializeWithHandlers(mclDefaultErrorHandler,
                                       mclDefaultPrintHandler);
}

LIB_fo_trak_C_API 
void MW_CALL_CONV fo_trakTerminate(void)
{
  if (_mcr_inst != NULL)
    mclTerminateInstance(&_mcr_inst);
}

int run_main(int argc, const char **argv)
{
  int _retval;
  /* Generate and populate the path_to_component. */
  char path_to_component[(PATH_MAX*2)+1];
  separatePathName(argv[0], path_to_component, (PATH_MAX*2)+1);
  __MCC_fo_trak_component_data.path_to_component = path_to_component; 
  if (!fo_trakInitialize()) {
    return -1;
  }
  argc = mclSetCmdLineUserData(mclGetID(_mcr_inst), argc, argv);
  _retval = mclMain(_mcr_inst, argc, argv, "olympiadTrak", 1);
  if (_retval == 0 /* no error */) mclWaitForFiguresToDie(NULL);
  fo_trakTerminate();
  mclTerminateApplication();
  return _retval;
}

int main(int argc, const char **argv)
{
  if (!mclInitializeApplication(
    __MCC_fo_trak_component_data.runtime_options,
    __MCC_fo_trak_component_data.runtime_option_count))
    return 0;
  
  return mclRunMain(run_main, argc, argv);
}
