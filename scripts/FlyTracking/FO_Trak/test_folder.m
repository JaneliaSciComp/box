workDir = 'O:\Olympiad Screen 2010\box\Analyzed\GMR_14E05_AE_01_shi_Apollo_20100201T144318'
outDir = 'O:\Olympiad Screen 2010\box\02_tracked\FTracked\GMR_14E05_AE_01_shi_Apollo_20100201T144318'
success = run_folder(workDir, outDir);


workDir = 'O:\Olympiad Screen 2010\box\01_sbfmf_compressed\GMR_14E08_AE_01_shi_Athena_20100201T145220'
outDir = 'O:\Olympiad Screen 2010\box\02_tracked\FTracked\GMR_14E08_AE_01_shi_Athena_20100201T145220'
success = run_folder(workDir, outDir);




% % to run just one folder:
% inputFile = 'O:\compressed\GMR_15A03_AE_01_shi_Zeus_20100204T145410\01_3.0_24\01_3.0_tube1_sbfmf\01_3.0_seq1_tube1.sbfmf';
% outputDir =  'C:\MatlabRoot\testing_cmdline_flytrack\GMR_15A03_AE_01_shi_Zeus_20100204T145410\Output\01_3.0_seq1_tube1';
% paramFile = 'C:\MatlabRoot\testing_cmdline_flytrack\params_olympiad.txt'
% [Trak_success] = olympiadTrak(paramFile, inputFile, outputDir);

