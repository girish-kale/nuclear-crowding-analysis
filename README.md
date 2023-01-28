# nuclear-crowding-analysis
A pipeline to generate pseudo-cells, starting from xyczt stack

Start with 'staging_assist.ijm' macro to...

	generate a folder automatically inside the main folder containing the raw data (raw= xyczt stack).
	save the raw data specific to certain timepoints of interest in the new folder, called 'interphase nuclei count'.

Then, use 'nuclei_domain_size.ijm' macro to...

	generate a folder automatically inside the 'interphase nuclei count' folder, called 'nuclear domain size analysis'.
	go over various timepoints from all the embryos that are in the same raw data folder.
	do the following for each timepoint...
		select the data for analysis (crop in xyz).
		perform semi-automated segmentation, where nuclei are detected as local maxima, and then corrected manually.
		generate areas around each nucleus such that the edges of the area are equidistant from neighboring nuclei.
		get the areas and x-y coordinates of the segmented areas, called "pseudo-cells".
		save all the relevant data including...
			xyz croped stack and its MAX projection
			detected nuclei as image with dots
			ImageJ ROIs for each segmented nucleus
			pseudo cells as tesselated image with pixel intensity derived from the cell area
			data file with areas and xy coordinates of the pseudo-cells

Finally, use 'nuclei_domain_size_data_analysis_fit.ijm' macro to...

	select all the raw data folders to get all the data files from the same treatment.
	consolidate the data from these data files.
	export the data in a format that is specifically useful for direct import into GraphPad Prism.

The other ImageJ macro files included here could be used for correcting errors, without having to start the whole analysis from scratch
	
	use 'nuclear_domain_size_redo.ijm' to...
		reload the segmentation and start from there
	use 'nuclear_domain_size_reanalyze.ijm' to...
		specifically process some timepoints without affecting others, starting from scratch
