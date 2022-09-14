To run all experiments in the local 00_incoming through the pipeline the same way that Hudson does:

1. cd to where the scripts have been checked out, somewhere like:
	/groups/flyprojects/home/olympiad/box/pipelines/manual/scripts
2. Store the metadata in SAGE (can be skipped if not using SAGE):
	./MetadataLoader/metadata_loader.pl run;
	./MetadataLoader/metadata_loader_QC.pl;
	./TransferApp/transfer_QC.pl;
3. Split out the tube movies:
	./TubeSplitter/avi_extract.sh;
	# Wait for cluster jobs to finish...
4. Convert the tube movies to SBFMF:
	./SBFMFConversion/avi_sbfmf_conversion.sh;
	# Wait for cluster jobs to finish...
5. Track the flies in the movies:
	./FlyTracking/fotrak.sh;
	# Wait for cluster jobs to finish...
6. Merge the tracking data:
	./MergeTracking/merge_fotrak.sh;
	# Wait for cluster jobs to finish...
7. Store the tracking data in SAGE (can be skipped if not using SAGE):
	./TrackingLoader/store_tracking.sh;
	# Wait for cluster jobs to finish...
8. Analyze the experiments:
	./Analysis/analysis.sh;
	# Wait for cluster jobs to finish...
9. Compress the AVI files:
	./AVICompression/avi_compression.sh;
	# Wait for cluster jobs to finish...
10. Archive the experiments:
	./Archiving/archive.sh;
    # Runs directly, no cluster jobs
