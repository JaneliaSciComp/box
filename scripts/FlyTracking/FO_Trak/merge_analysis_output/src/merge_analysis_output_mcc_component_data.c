/*
 * MATLAB Compiler: 4.9 (R2008b)
 * Date: Mon Apr  5 22:16:37 2010
 * Arguments: "-B" "macro_default" "-o" "merge_analysis_output" "-W" "main"
 * "-d" "/groups/flyprojects/home/olympiad/FO_Trak/merge_analysis_output/src"
 * "-T" "link:exe" "-R" "-nojvm" "-N"
 * "/groups/flyprojects/home/olympiad/FO_Trak/merge_analysis_output.m" "-a"
 * "/groups/flyprojects/home/olympiad/FO_Trak/Olympiad_folder_check.m" 
 */

#include "mclmcrrt.h"

#ifdef __cplusplus
extern "C" {
#endif
const unsigned char __MCC_merge_analysis_output_session_key[] = {
    'B', 'A', '2', 'F', 'F', '6', '5', '5', 'E', '0', 'A', '8', 'F', 'A', 'F',
    'B', '3', 'C', '6', 'A', 'B', 'F', '5', '9', '0', '7', '8', '1', 'D', '9',
    '3', '1', 'E', '7', 'D', 'F', '9', '6', '8', 'D', '4', '8', '6', '9', '5',
    '0', '9', '0', '8', 'F', '5', '0', '1', '1', '5', '4', 'A', 'C', 'A', '0',
    '8', '2', '9', 'F', '5', '2', '5', '1', '5', '3', 'A', 'B', 'F', 'F', '3',
    '4', '7', '2', '5', 'F', 'E', '9', '9', 'B', '2', 'D', 'B', '6', '9', '6',
    'A', '5', 'F', '8', '8', '4', 'F', '2', '5', '8', '3', 'A', '0', 'C', '7',
    '8', '8', '1', 'D', '7', '7', '8', '0', '7', '7', 'D', '0', 'A', '4', '5',
    '3', 'F', 'F', '9', 'A', '7', '4', 'D', '2', '3', 'D', '6', '3', '3', '0',
    '3', '6', '2', 'E', '9', '1', '0', '4', '1', '0', '5', '5', '7', '1', '1',
    '3', '3', 'D', '7', '1', '4', '9', 'A', 'A', '3', 'B', '1', '4', '7', 'C',
    '4', 'B', 'D', '1', 'E', '9', '3', '2', '9', 'D', 'B', 'F', '6', '3', '5',
    '1', '7', '6', '1', '9', '1', 'B', '0', '9', 'B', 'A', 'B', '3', '5', 'D',
    '7', 'A', '5', '6', '7', 'F', '4', '0', '6', 'A', '4', '2', '9', '5', 'A',
    '9', 'C', '5', 'F', '2', '3', 'D', 'F', '5', 'E', '1', '7', '6', '0', '8',
    '3', 'F', '8', '6', 'E', 'D', '8', '5', '2', '2', 'B', 'D', '8', '5', '5',
    '9', '3', '6', '3', '0', '2', '0', '1', 'B', 'D', 'C', 'E', '5', '2', '2',
    '2', '\0'};

const unsigned char __MCC_merge_analysis_output_public_key[] = {
    '3', '0', '8', '1', '9', 'D', '3', '0', '0', 'D', '0', '6', '0', '9', '2',
    'A', '8', '6', '4', '8', '8', '6', 'F', '7', '0', 'D', '0', '1', '0', '1',
    '0', '1', '0', '5', '0', '0', '0', '3', '8', '1', '8', 'B', '0', '0', '3',
    '0', '8', '1', '8', '7', '0', '2', '8', '1', '8', '1', '0', '0', 'C', '4',
    '9', 'C', 'A', 'C', '3', '4', 'E', 'D', '1', '3', 'A', '5', '2', '0', '6',
    '5', '8', 'F', '6', 'F', '8', 'E', '0', '1', '3', '8', 'C', '4', '3', '1',
    '5', 'B', '4', '3', '1', '5', '2', '7', '7', 'E', 'D', '3', 'F', '7', 'D',
    'A', 'E', '5', '3', '0', '9', '9', 'D', 'B', '0', '8', 'E', 'E', '5', '8',
    '9', 'F', '8', '0', '4', 'D', '4', 'B', '9', '8', '1', '3', '2', '6', 'A',
    '5', '2', 'C', 'C', 'E', '4', '3', '8', '2', 'E', '9', 'F', '2', 'B', '4',
    'D', '0', '8', '5', 'E', 'B', '9', '5', '0', 'C', '7', 'A', 'B', '1', '2',
    'E', 'D', 'E', '2', 'D', '4', '1', '2', '9', '7', '8', '2', '0', 'E', '6',
    '3', '7', '7', 'A', '5', 'F', 'E', 'B', '5', '6', '8', '9', 'D', '4', 'E',
    '6', '0', '3', '2', 'F', '6', '0', 'C', '4', '3', '0', '7', '4', 'A', '0',
    '4', 'C', '2', '6', 'A', 'B', '7', '2', 'F', '5', '4', 'B', '5', '1', 'B',
    'B', '4', '6', '0', '5', '7', '8', '7', '8', '5', 'B', '1', '9', '9', '0',
    '1', '4', '3', '1', '4', 'A', '6', '5', 'F', '0', '9', '0', 'B', '6', '1',
    'F', 'C', '2', '0', '1', '6', '9', '4', '5', '3', 'B', '5', '8', 'F', 'C',
    '8', 'B', 'A', '4', '3', 'E', '6', '7', '7', '6', 'E', 'B', '7', 'E', 'C',
    'D', '3', '1', '7', '8', 'B', '5', '6', 'A', 'B', '0', 'F', 'A', '0', '6',
    'D', 'D', '6', '4', '9', '6', '7', 'C', 'B', '1', '4', '9', 'E', '5', '0',
    '2', '0', '1', '1', '1', '\0'};

static const char * MCC_merge_analysis_output_matlabpath_data[] = 
  { "merge_analys/", "$TOOLBOXDEPLOYDIR/", "$TOOLBOXMATLABDIR/general/",
    "$TOOLBOXMATLABDIR/ops/", "$TOOLBOXMATLABDIR/lang/",
    "$TOOLBOXMATLABDIR/elmat/", "$TOOLBOXMATLABDIR/randfun/",
    "$TOOLBOXMATLABDIR/elfun/", "$TOOLBOXMATLABDIR/specfun/",
    "$TOOLBOXMATLABDIR/matfun/", "$TOOLBOXMATLABDIR/datafun/",
    "$TOOLBOXMATLABDIR/polyfun/", "$TOOLBOXMATLABDIR/funfun/",
    "$TOOLBOXMATLABDIR/sparfun/", "$TOOLBOXMATLABDIR/scribe/",
    "$TOOLBOXMATLABDIR/graph2d/", "$TOOLBOXMATLABDIR/graph3d/",
    "$TOOLBOXMATLABDIR/specgraph/", "$TOOLBOXMATLABDIR/graphics/",
    "$TOOLBOXMATLABDIR/uitools/", "$TOOLBOXMATLABDIR/strfun/",
    "$TOOLBOXMATLABDIR/imagesci/", "$TOOLBOXMATLABDIR/iofun/",
    "$TOOLBOXMATLABDIR/audiovideo/", "$TOOLBOXMATLABDIR/timefun/",
    "$TOOLBOXMATLABDIR/datatypes/", "$TOOLBOXMATLABDIR/verctrl/",
    "$TOOLBOXMATLABDIR/codetools/", "$TOOLBOXMATLABDIR/helptools/",
    "$TOOLBOXMATLABDIR/demos/", "$TOOLBOXMATLABDIR/timeseries/",
    "$TOOLBOXMATLABDIR/hds/", "$TOOLBOXMATLABDIR/guide/",
    "$TOOLBOXMATLABDIR/plottools/", "toolbox/local/",
    "$TOOLBOXMATLABDIR/datamanager/", "toolbox/compiler/" };

static const char * MCC_merge_analysis_output_classpath_data[] = 
  { "" };

static const char * MCC_merge_analysis_output_libpath_data[] = 
  { "" };

static const char * MCC_merge_analysis_output_app_opts_data[] = 
  { "" };

static const char * MCC_merge_analysis_output_run_opts_data[] = 
  { "-nojvm" };

static const char * MCC_merge_analysis_output_warning_state_data[] = 
  { "off:MATLAB:dispatcher:nameConflict" };


mclComponentData __MCC_merge_analysis_output_component_data = { 

  /* Public key data */
  __MCC_merge_analysis_output_public_key,

  /* Component name */
  "merge_analysis_output",

  /* Component Root */
  "",

  /* Application key data */
  __MCC_merge_analysis_output_session_key,

  /* Component's MATLAB Path */
  MCC_merge_analysis_output_matlabpath_data,

  /* Number of directories in the MATLAB Path */
  37,

  /* Component's Java class path */
  MCC_merge_analysis_output_classpath_data,
  /* Number of directories in the Java class path */
  0,

  /* Component's load library path (for extra shared libraries) */
  MCC_merge_analysis_output_libpath_data,
  /* Number of directories in the load library path */
  0,

  /* MCR instance-specific runtime options */
  MCC_merge_analysis_output_app_opts_data,
  /* Number of MCR instance-specific runtime options */
  0,

  /* MCR global runtime options */
  MCC_merge_analysis_output_run_opts_data,
  /* Number of MCR global runtime options */
  1,
  
  /* Component preferences directory */
  "merge_analys_D5A0355D60B76047C0023C2F3F5F0EAF",

  /* MCR warning status data */
  MCC_merge_analysis_output_warning_state_data,
  /* Number of MCR warning status modifiers */
  1,

  /* Path to component - evaluated at runtime */
  NULL

};

#ifdef __cplusplus
}
#endif


