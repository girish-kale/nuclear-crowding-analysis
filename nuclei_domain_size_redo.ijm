//run("Set Measurements...", "area mean centroid center redirect=None decimal=6");
//run("Set Measurements...", "area centroid perimeter shape redirect=None decimal=6");
run("Set Measurements...", "area mean standard min centroid center perimeter shape redirect=None decimal=6");			

waitForUser("reminder to install Drawing-tools");

folder=getDirectory("Choose a folder with embryo images"); // this should be the 'interphase nuclei count' folder
target=folder+"/nuclear domain size analysis/";

files=getFileList(target);

roiManager("reset");

firstFile=getNumber("starting file number =", 1);
firstFile=firstFile-1;

file=0;		fileCounter=0;
do{ // DO-WHILE loop through files
	
	if (startsWith(files[file],"Dme_") && endsWith(files[file], "_stack.tif") ) { // IF statement to pick specific processed TIFF files
		
		fileCounter=fileCounter+1;

		if (fileCounter>firstFile) { // IF statement to start processing from a specific file
			
			open(target+files[file]);		longName=File.nameWithoutExtension;
			
			name=substring(longName, 0, indexOf(longName, "_a-"));
	
			stage=substring(name, indexOf(name,"inter")+6, indexOf(name,"inter")+8 );		stage=parseInt(stage);
	
			getVoxelSize(wid, hei, depth, unit);		rename(name+"_stack");
	
			roiManager("Open", target+"cropbox_"+name+".roi");
	
			selectWindow(name+"_stack");	roiManager("select",0);		run("Crop");
			run("Select None");				roiManager("reset");		//run("32-bit");
	
			if(stage==10 || stage==11){ //  IF statement for stage dependent outlier clean-up
				run("Remove Outliers...", "radius=10 threshold=100 which=Bright stack");
			}
			run("Gaussian Blur...", "sigma=1 stack");		run("Z Project...", "projection=[Max Intensity]");		
				
			close(name+"_stack");
			
			selectWindow("MAX_"+name+"_stack");			run("Median...", "radius=1");		rename(name);		run("HiLo");

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			open(target+"Seeds_"+name+".tif");		rename(name+" Maxima");
			
			run("Merge Channels...", "c1=["+name+" Maxima] c4=["+name+"] create");
	
			if(stage==10 || stage==11){ //  IF statement for stage dependent contrast adjustment
				setSlice(2);		setMinAndMax(8, 200);		setSlice(1);
				
			}else{
				setSlice(2);		setMinAndMax(8, 400);		setSlice(1);
					
			} //  IF statement for stage dependent contrast adjustment

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// finally adding a few manual touches, using paintbrush tool, to make sure that the segmentation is optimal.
// Ideally, the added touch-ups should be of different size, as compared to automated ones generated above.
	
		do{ // loop to manually correct the identified nuclei
	
			setTool("Paintbrush Tool");	// IJ.getToolName();		
			Dialog.createNonBlocking("First quality control"); /// pause for manual input ///////////////////////////////////////////////
			Dialog.addMessage("Pause to manually check and mark the nuclei\nuse the paintbrush to edit the nuclei segmentation\n"+name);
			Dialog.setLocation(1300,-200);
			//Dialog.setLocation(1100, 700);
			Dialog.show();
			
			selectWindow("Composite");		run("Split Channels");
			
			selectWindow("C1-Composite");		//rename(name);
	
			run("Find Maxima...", "prominence=150 exclude output=[Single Points]"); // 150 is just arbitrary high enough value
			selectWindow("C1-Composite Maxima");
			run("Voronoi");
			
			setAutoThreshold("Default dark");
			//run("Threshold...");
			setThreshold(1, 255);		run("Convert to Mask");			run("Invert");
		
			run("Analyze Particles...", "size=40-Infinity pixel circularity=0.00-1.00 exclude add"); // 40 here is NOT 40 sqr um
	
			selectWindow("C1-Composite Maxima");		close("C1-Composite Maxima");
	
			selectWindow("C1-Composite");		rename(name+" Maxima");
			selectWindow("C2-Composite");		rename(name);

////////////////////////////////////////////////////////////////////////////////////
// a preliminary filter 
// many ROIs tend to stretch out outside the embryo. So, these can be excluded using the fact that the minimum pixel value
// for these would be quite low
// note that the criterion is objective
	
			run("Clear Results");		selectWindow(name);		roiManager("deselect");			roiManager("measure");
			
			deletion="";
			
			for (i=0; i<nResults; i++) { // FOR loop to filter out the outlier ROIs
				
				if (getResult("Min", i)<10){ // any ROI that sticks out beyond the embryo is marked for deletion
					
					deletion=deletion+i+",";
					
				} // any ROI that sticks out beyond the embryo is marked for deletion
				// also, this works because nResults==roiManager("count")
								
			} // FOR loop to filter out the outlier ROIs
			
			existance=indexOf(deletion,",");
			if (existance>0) {
	
				deletion=substring(deletion,0,lastIndexOf(deletion, ","));		deleted=split(deletion,",");
	
				for (i=1; i<deleted.length+1; i++){
					// each deleted roi makes the roi-list progressively shorter, hence going backwards.
					// Also, the second argument in roiManager("select",...) is a string
					roiManager("select", deleted[deleted.length-i]);		roiManager("delete");
				}
			}
			
			run("Clear Results");
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			run("Merge Channels...", "c1=["+name+" Maxima] c4=["+name+"] create");		roiManager("Show All without labels");
	
			Dialog.createNonBlocking("Second quality control"); /// pause for manual input ///////////////////////////////////////////////
			Dialog.addMessage("The segmentation should isolate the nuclei");
			Dialog.addCheckbox("Yes?", false);
			Dialog.setLocation(1300,-200);
			//Dialog.setLocation(1100,700);
			Dialog.show();
			
			condition=Dialog.getCheckbox();
	
				if (condition==0){
					roiManager("reset");
				}else{
					selectWindow("Composite");			run("Split Channels");
					selectWindow("C1-Composite");		rename(name+" Maxima");
					selectWindow("C2-Composite");		rename(name);
				}
				
			setTool("rectangle");
			
			}while (condition==0) // loop to manually correct the identified nuclei
			
			selectWindow(name+" Maxima");		roiManager("deselect");		run("Remove Overlay");		setMinAndMax(0, 255);
			save(target+"Seeds_"+name+".tif");
			
			close("*"); // only thing remaining now is the ROIs in the manager
			
			roiManager("Save", target+"Regions_"+name+"_old.zip");
			
// A preliminary segmentation is now ready. This will be refined below to remove outliers			
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

			open(target+"MAX_"+name+".tif");		roiManager("deselect");		roiManager("measure");

////////////////////////////////////////////////////////////////////////////////////
// first filter using the aspect ratio (AR) and circularity (Circ.) of the ROIs, and whether they contain their centroid or not
// note that all criteria here are objective
			deletion="";
			
			for (i=0; i<nResults; i++) { // FOR loop to filter out the outlier ROIs
				x=getResult("X",i);			y=getResult("Y",i);			toUnscaled(x, y);
				roiManager("select",i);		balanced=Roi.contains(x, y); // balanced==1 if ROI contains its centroid
				// also, this works because nResults==roiManager("count")
				
				if (getResult("AR", i)>2 || balanced==0){ // circularity condition is dropped here as that gets rid of most positive detections as well
					deletion=deletion+i+",";
				} // any ROI that doesn't contain its centroid, or that's too elongated is marked for deletion
								
			} // FOR loop to filter out the outlier ROIs
			
			existance=indexOf(deletion,",");
			if (existance>0) {
	
				deletion=substring(deletion,0,lastIndexOf(deletion, ","));		deleted=split(deletion,",");
	
				for (i=1; i<deleted.length+1; i++){
					// each deleted roi makes the roi-list progressively shorter, hence going backwards.
					// Also, the second argument in roiManager("select",...) is a string
					roiManager("select", deleted[deleted.length-i]);		roiManager("delete");
				}
			}
			run("Clear Results");		roiManager("deselect");			roiManager("measure");

////////////////////////////////////////////////////////////////////////////////////
// second filter using the mean intensity 'means' and the area of the ROIs 'area'
// note that all criteria here are subjective
			deletion="";
			
			means=Table.getColumn("Mean");			areas=Table.getColumn("Area");
			Array.getStatistics(means, min_means, max_means, mean_means, stdDev_means); //Array.getStatistics(array, min, max, mean, stdDev);
			Array.getStatistics(areas, min_areas, max_areas, mean_areas, stdDev_areas);
			
			for (i=0; i<nResults; i++) { // FOR loop to filter out the outlier ROIs
				if (getResult("Mean",i)<mean_means/3 || getResult("Mean", i)>mean_means*3 || getResult("Area", i)<mean_areas/2 || getResult("Area", i)>mean_areas*2){
					deletion=deletion+i+",";
				} // any ROI that is too dim, too bright, too big, or too small is marked for deletion
			} // FOR loop to filter out the outlier ROIs
			
			existance=indexOf(deletion,",");
			if (existance>0) {
	
				deletion=substring(deletion,0,lastIndexOf(deletion, ","));		deleted=split(deletion,",");
	
				for (i=1; i<deleted.length+1; i++){
					// each deleted roi makes the roi-list progressively shorter, hence going backwards.
					// Also, the second argument in roiManager("select",...) is a string
					roiManager("select", deleted[deleted.length-i]);		roiManager("delete");
				}
			}

// ROI filtering finished
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
			run("Clear Results");		roiManager("deselect");			roiManager("measure");
	
			roiManager("Save", target+"/Regions_"+name+".zip");					
			saveAs("Results", target+"/Data_"+name+".csv");

// saved ROIs and data
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// now generating heat maps for the areas
			selectWindow("MAX_"+name+".tif");		rename(name);		run("8-bit");		run("Multiply...", "value=0");
			roiManager("Show All without labels");		roiManager("Set Fill Color", "white stack");
			run("Flatten");			close(name);		rename(name);		run("16-bit");			roiManager("reset");
	
			areas=Table.getColumn("Area");			
			
			run("Colors...", "foreground=white background=black selection=white"); // set foreground color and selection color to White
	
			for (i=0; i<nResults; i++) { // FOR loop to color the ROIs according to their area
				ROIarea=getResult("Area",i);		x=getResult("X",i);			y=getResult("Y",i);		toUnscaled(x, y);
				selectWindow(name);		setMinAndMax(0, round(ROIarea*10));		floodFill(x, y);
			}
	
			setMinAndMax(100,10000);			run("Fire");
			roiManager("open", target+"/Regions_"+name+".zip");
			roiManager("Show All without labels");
			
			save(target+"Nuclei_domains_"+name+".tif");

// saved a heat-map of areas
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			roiManager("reset");	run("Clear Results");	close("*");		run("Collect Garbage");

			firstFile=firstFile+5;
		} // IF statement to start processing from a specific file
		
	} // IF statement to pick specific processed TIFF files

	file=file+1;
} while(file<files.length) // DO-WHILE loop through files 

exit();

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////




roiManager("Set Fill Color", "white");
roiManager("Set Fill Color", "");

run("Gaussian Blur...", "sigma=1 stack");
run("Gaussian Blur...", "sigma=1");

//setAutoThreshold("Default dark");
			//run("Threshold...");
			//setOption("BlackBackground", true);
			//run("Convert to Mask");
			//run("Make Binary");
			
			//run("Options...", "iterations=3 count=5 do=Close");			run("Options...", "iterations=3 count=5 black do=Close");
			//run("Options...", "iterations=10 count=4 black do=Dilate");
			//run("Analyze Particles...", "size=40-Infinity pixel display clear add");

			//run("Voronoi");
			//setAutoThreshold("Default");			setThreshold(1, 255);
			//setOption("BlackBackground", true);		run("Convert to Mask");		run("Make Binary");			//run("Options...", "iterations=1 count=1 black do=Dilate");
			//run("Invert");				run("Analyze Particles...", "size=0-Infinity pixel display exclude clear add"); // add circularity condition here


							//if (ROIarea<min){ // IF...ELSE statements to color code cells based on their nuclear domain size 
				//	grayArea=0;
				//}else if(ROIarea>max){
				//	grayArea=255;
				//}else{
				//	grayArea=floor(255*(ROIarea-min)/(max-min));
				//}
				setForegroundColor(grayArea,grayArea,grayArea);			selectWindow(dapi);		floodFill(x, y);


//		existanceCellularization=indexOf(name,"inter-14");
// IF statement to determine the number of z-slices to be projected.
// The number of z-slices depends on 1) the height of a tallest nucleus (~12-13um) and 2) the stage of the embryo
//		if (existanceCellularization < 0) { // syncytial embryo
			// projecting more slices if the embryo is in syncytial blastoderm
//			basal=minOf(floor(24/depth)+apical-1,nSlices); // 24 is in 'um'	
		
//		} else { // cellularizing embryo
			// projecting fewer slices if the embryo is in cellularization
//			basal=minOf(floor(12/depth)+apical-1,nSlices); // 12 is in 'um'
//		}