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

#include "mclmcrrt.h"

#ifdef __cplusplus
extern "C" {
#endif
const unsigned char __MCC_fo_trak_session_key[] = {
    'A', '0', '3', 'E', '6', 'E', 'E', '3', 'C', '8', '1', 'C', 'F', 'B', 'D',
    'C', '2', '1', '8', '9', '1', 'E', 'D', '8', 'C', 'B', '4', 'C', 'E', '1',
    'E', '6', 'E', '2', 'B', 'A', 'A', '0', '6', 'A', 'E', 'C', 'C', '0', 'E',
    'E', '7', '2', 'F', '3', '0', '7', 'A', '2', 'A', '1', 'C', '9', '7', '2',
    'C', 'E', '7', '2', 'D', '5', 'E', '4', '5', 'A', '6', '8', 'C', 'B', 'E',
    '6', '1', 'B', '3', 'F', 'D', 'E', '0', 'D', '7', '4', '5', '8', '3', 'C',
    '6', '8', '3', 'B', '8', 'A', '0', '2', 'C', '2', '4', '1', '4', 'B', 'B',
    '4', 'B', '4', '9', '1', 'B', 'D', 'F', 'C', 'A', '3', '5', '5', '2', '2',
    '1', '1', '1', '2', 'E', 'E', 'F', 'D', '4', '9', 'E', 'C', 'A', '6', 'F',
    'C', '5', '9', 'C', '0', 'D', 'A', 'F', '8', 'F', 'D', '4', '7', '9', '8',
    '1', '2', '0', '9', '0', 'B', 'B', '3', '5', '5', '1', '5', '2', 'A', '7',
    'E', '8', '8', '6', '7', 'E', '5', 'D', '8', 'B', '2', '5', '5', '0', '1',
    '6', '1', '7', '6', '9', 'A', 'B', 'F', 'A', 'E', 'E', '1', 'C', '6', 'F',
    '4', '0', 'E', '9', 'D', '0', 'E', '6', '6', 'A', '6', 'B', '2', '1', 'B',
    '9', '8', 'F', '2', '7', '1', '1', '8', 'E', '3', '8', 'F', '4', '4', '2',
    'B', '5', '2', 'D', '6', 'C', 'E', '9', 'A', '1', '3', 'D', '6', '8', '6',
    'C', '1', 'B', '6', '7', '6', '4', '4', 'D', 'C', '6', '1', '7', 'E', '7',
    '2', '\0'};

const unsigned char __MCC_fo_trak_public_key[] = {
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

static const char * MCC_fo_trak_matlabpath_data[] = 
  { "fo_trak/", "$TOOLBOXDEPLOYDIR/", "utils/",
    "$TOOLBOXMATLABDIR/general/", "$TOOLBOXMATLABDIR/ops/",
    "$TOOLBOXMATLABDIR/lang/", "$TOOLBOXMATLABDIR/elmat/",
    "$TOOLBOXMATLABDIR/randfun/", "$TOOLBOXMATLABDIR/elfun/",
    "$TOOLBOXMATLABDIR/specfun/", "$TOOLBOXMATLABDIR/matfun/",
    "$TOOLBOXMATLABDIR/datafun/", "$TOOLBOXMATLABDIR/polyfun/",
    "$TOOLBOXMATLABDIR/funfun/", "$TOOLBOXMATLABDIR/sparfun/",
    "$TOOLBOXMATLABDIR/scribe/", "$TOOLBOXMATLABDIR/graph2d/",
    "$TOOLBOXMATLABDIR/graph3d/", "$TOOLBOXMATLABDIR/specgraph/",
    "$TOOLBOXMATLABDIR/graphics/", "$TOOLBOXMATLABDIR/uitools/",
    "$TOOLBOXMATLABDIR/strfun/", "$TOOLBOXMATLABDIR/imagesci/",
    "$TOOLBOXMATLABDIR/iofun/", "$TOOLBOXMATLABDIR/audiovideo/",
    "$TOOLBOXMATLABDIR/timefun/", "$TOOLBOXMATLABDIR/datatypes/",
    "$TOOLBOXMATLABDIR/verctrl/", "$TOOLBOXMATLABDIR/codetools/",
    "$TOOLBOXMATLABDIR/helptools/", "$TOOLBOXMATLABDIR/demos/",
    "$TOOLBOXMATLABDIR/timeseries/", "$TOOLBOXMATLABDIR/hds/",
    "$TOOLBOXMATLABDIR/guide/", "$TOOLBOXMATLABDIR/plottools/",
    "toolbox/local/", "$TOOLBOXMATLABDIR/datamanager/", "toolbox/compiler/",
    "toolbox/images/colorspaces/", "toolbox/images/images/",
    "toolbox/images/imuitools/", "toolbox/images/iptformats/",
    "toolbox/images/iptutils/", "toolbox/shared/imageslib/" };

static const char * MCC_fo_trak_classpath_data[] = 
  { "java/jar/toolbox/images.jar" };

static const char * MCC_fo_trak_libpath_data[] = 
  { "" };

static const char * MCC_fo_trak_app_opts_data[] = 
  { "" };

static const char * MCC_fo_trak_run_opts_data[] = 
  { "-nojvm" };

static const char * MCC_fo_trak_warning_state_data[] = 
  { "off:MATLAB:dispatcher:nameConflict" };


mclComponentData __MCC_fo_trak_component_data = { 

  /* Public key data */
  __MCC_fo_trak_public_key,

  /* Component name */
  "fo_trak",

  /* Component Root */
  "",

  /* Application key data */
  __MCC_fo_trak_session_key,

  /* Component's MATLAB Path */
  MCC_fo_trak_matlabpath_data,

  /* Number of directories in the MATLAB Path */
  44,

  /* Component's Java class path */
  MCC_fo_trak_classpath_data,
  /* Number of directories in the Java class path */
  1,

  /* Component's load library path (for extra shared libraries) */
  MCC_fo_trak_libpath_data,
  /* Number of directories in the load library path */
  0,

  /* MCR instance-specific runtime options */
  MCC_fo_trak_app_opts_data,
  /* Number of MCR instance-specific runtime options */
  0,

  /* MCR global runtime options */
  MCC_fo_trak_run_opts_data,
  /* Number of MCR global runtime options */
  1,
  
  /* Component preferences directory */
  "fo_trak_6AA7F67EC6B0BCFCE56F4A2AE7BAB375",

  /* MCR warning status data */
  MCC_fo_trak_warning_state_data,
  /* Number of MCR warning status modifiers */
  1,

  /* Path to component - evaluated at runtime */
  NULL

};

#ifdef __cplusplus
}
#endif


