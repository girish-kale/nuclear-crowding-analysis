// Here select and save the timepoints corresponding to a specific interphase during the syncytial blastoderm nuclear divisions.
// The choice of the timepoint that represents the interphase can be subjective, as there are multiple timepoints which would correspond
// to the same interphase. By choice, we will select the last timepoint where each nucleus in the field-of-view is in the interphase.
//
// We open the entire hyperstacks of embyos and a corresponding MAX projected time series to identify the end of interphases.
// The macro will only process interphases 10 through 14

run("Set Measurements...", "area mean standard centroid center perimeter shape redirect=None decimal=6");

inf=0;
while (inf==0){ // an infinite loop to keep going through embryo-after-embryo
	
	File.openDialog("Choose the hyperstack");
	
	name=File.nameWithoutExtension;
	folder=File.directory;
	
	open(folder+name+".tif");
	getDimensions(width, height, channels, slices, frames);
	
	open(folder+"MAX_"+name+".tif");

// a simple loop over syncytial blastoderm interpahses 10 to 14 /////////////////////////////////////////////////

	stage=10;
	
	while (stage<15) {
		
		selectWindow("MAX_"+name+".tif");
	
		Dialog.createNonBlocking("select frame for...");
		Dialog.addMessage("interphase "+stage);
		Dialog.setLocation(1300,-400);
		Dialog.show();
	
		Stack.getPosition(channel, slice, frame);
		
		selectWindow(name+".tif");
		run("Duplicate...", "title=["+name+"_inter-"+stage+"_t"+frame+"] duplicate channels=1-2 slices=1-"+slices+" frames="+frame);
		run("Grays");
	
		stage=stage+1;
	}
// done copying timepoints corresponding to all stages of interest //////////////////////////////////////////////////////////////

// So, now we close all the big images //////////////////////////////////////////////////////////////////////////////////////////		
	close("MAX_"+name+".tif");	close(name+".tif");
	
// making the new directory here. In principle, we could have done this at the beginning	
	target=folder+"interphase nuclei count/";		File.makeDirectory(target);
	
// following piece of code is similar to the custom macro 'save all'
	images=getList("image.titles");
	
	for (i=0; i<images.length; i++) {
		selectImage(images[i]);
		saveAs("TIFF...", target+images[i]);
		close(images[i]+"*");
	}
// all images saved

} // an infinite loop to keep going through embryo-after-embryo

exit();
