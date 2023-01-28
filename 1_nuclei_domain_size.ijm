//run("Set Measurements...", "area mean centroid center redirect=None decimal=6");
//run("Set Measurements...", "area centroid perimeter shape redirect=None decimal=6");
run("Set Measurements...", "area mean standard min centroid center perimeter shape redirect=None decimal=6");			

waitForUser("reminder to install Drawing-tools");		dialogX=1300;		dialogY=-200; //900;

folder=getDirectory("Choose a folder with embryo images"); // this should be the 'interphase nuclei count' folder
files=getFileList(folder);
File.makeDirectory(folder+"/nuclear domain size analysis/");

file=0;		default=4;
do{ // DO-WHILE loop through files 
	if (startsWith(files[file],"Dme_")) { // IF statement to pick TIFF files
		open(folder+files[file]);		name=File.nameWithoutExtension;		//run("Maximize");

//		species=substring(name,0,indexOf(name,"_"));
//		dapi=substring(name,0,indexOf(name,"Phalla")-1)+substring(name,indexOf(name,"- "+species)+5);
//		existance10=indexOf(name,"inter_10");		existance11=indexOf(name,"inter_11");

		getVoxelSize(wid, hei, depth, unit);		run("Grays");		setMinAndMax(8, 128);		setSlice(1);

		Dialog.createNonBlocking(""); //// manual input ///////////////////////////////////////////////
		Dialog.addMessage("Identify the apical-most plane and click ok\n(We are processing file number "+file+")");
		Dialog.setLocation(dialogX,dialogY);
		Dialog.show();

		Stack.getPosition(channel, slice, frame);		apical=slice;
		
		stage=substring(name, indexOf(name,"inter")+6, indexOf(name,"inter")+8 );		stage=parseInt(stage);

// here we calculate the basal-most plane to determine the stack size. We are going to reduce the stack size for successive interphases.
// All of this is determined more-or-less empirically, and is rather subjective. The main objective is to control how many nuclei we have
// in the plane, in order to have a large enough number of nuclei for good sampling, as well as not having too many of them to have
// artefacts due to the curvature of the embryo. We are successively reducing the stack size by 4um, which should amount to a reduction of
// 2 z-slices. The minimun z-height would be 12um, which corresponds to height of late cellularization nuclei, while the maximum would be
// 28um which corresponds to the height of late cellularization cell.
		basal=minOf(round(4/depth)*(7-(stage-10))+(apical-1), nSlices);
		// 4 is in 'um', while '7-(stage-10)' is a convenient way of using the interphase number to calculate stack height

//channel 1 is His2Av::RFP marking the nuclei, and is hence duplicated		
		run("Duplicate...", "title=["+name+"_stack] duplicate channels=1 slices="+apical+"-"+basal+" frames=1");		close(name+".tif");
		stackLoc="_a-"+IJ.pad(apical,2)+"_b-"+IJ.pad(basal,2); // we'll use this to write the stackLocation in the file name
		save(folder+"/nuclear domain size analysis/"+name+stackLoc+"_stack.tif");		rename(name+"_stack");

		selectWindow(name+"_stack");
// MAX works better than SUM, as it gives a more uniform background.
		run("Z Project...", "projection=[Max Intensity]");		
			
		selectWindow("MAX_"+name+"_stack");		roiManager("reset");		setTool("rectangle");

		Dialog.createNonBlocking("");
		Dialog.addMessage("Draw a box to encapsulate the embryo and click ok");
		Dialog.setLocation(dialogX,dialogY);
		Dialog.show();
		roiManager("add");			roiManager("Save", folder+"/nuclear domain size analysis/cropbox_"+name+".roi");

		roiManager("select",0);			run("Crop");		run("Remove Overlay");		run("Grays");
		save(folder+"/nuclear domain size analysis/MAX_"+name+".tif");					close("MAX_"+name+".tif");
		close("MAX_"+name+"_stack");

// saved the original MAX projection to open it again later on
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

		selectWindow(name+"_stack");	roiManager("select",0);		run("Crop");
		run("Select None");				roiManager("reset");		//run("32-bit");

		if(stage==10 || stage==11){ //  IF statement for stage dependent outlier clean-up
			run("Remove Outliers...", "radius=10 threshold=100 which=Bright stack");
		}
		run("Gaussian Blur...", "sigma=1 stack");				//run("Maximum...", "radius=1 stack");
		run("Z Project...", "projection=[Max Intensity]");		
			
		close(name+"_stack");
		
		selectWindow("MAX_"+name+"_stack");			run("Median...", "radius=1");		rename(name);		run("HiLo");

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// here we are testing different thresholds to see which gives best segmentation

		stdevLevels=newArray("-1", "-0.75", "-0.5", "-0.25", "0", "0.25", "0.5", "0.75", "1", "1.25", "1.5");
		//stdevLevels=newArray("-1", "-0.75", "-0.5", "-0.25", "0", "0.25", "0.5", "0.75", "1", "1.25", "1.5"); // original
		
		//default=4;
		do{ //loop to test different thresholds

			Dialog.createNonBlocking("Threshold level selection");
			Dialog.addMessage("Threshold = Mean + x*(Stdev)");
			Dialog.addChoice("x=", stdevLevels, stdevLevels[default]);
			//Dialog.addChoice("x=", stdevLevels, default);
			Dialog.setLocation(dialogX,dialogY);
			Dialog.show();
			stdev=Dialog.getChoice();		stdev=parseFloat(stdev);
				
			default=4+stdev*4; // this works as long as the original stdevLevels array is not altered
			//defualt=4+stdev*4; // original
					
			selectWindow(name);		run("Measure");		thresh=getResult("Mean") + stdev*getResult("StdDev");	
			metadat="Threshold = Mean + x*(Stdev) "+thresh+" = "+getResult("Mean")+" + "+stdev+"*"+getResult("StdDev");
			run("Clear Results");		roiManager("reset");
			
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Now we'll try to detect maxima using the 'Find Maxima...' function. This needs to be used depending on the signal-to-noise 
// ratio of His2Av-RFP, which is kind of low during interpahse 10. So, that interphase will be processed differently.
// The IF and ELSE statements extract the (approximate) centers of nuclei in pixel either pixel coordinates or micron-scaled coordinates.
// Hence, they need to be processed differently as well.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
			
			if(stage==10 || stage==11){ //  IF statement for stage dependent maxima detection
				run("Find Maxima...", "prominence="+thresh+" output=List");

// most of the detected maxima are off-center. So trying to re-center them a bit.
// Using 'center of mass' instead of 'centroid' to identify the nucleus proper, as CoM takes into account the pixel intensity as well.
				base=10+5-floor((stage+1)/2);
				
// This first loop is just establishing the baseline
				selectWindow(name);	
				x=Table.getColumn("X");		y=Table.getColumn("Y");		run("Clear Results");
				for(coor=0; coor<x.length; coor++){
					makeOval(x[coor]-base, y[coor]-base, base*2, base*2);		run("Measure");
				}
			}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////			
			
			else{
				run("Find Maxima...", "prominence="+thresh+"  output=[Segmented Particles]");
				
				selectWindow(name+" Segmented");		
				run("Analyze Particles...", "size=40-Infinity pixel exclude add"); // 40 here is NOT 40 sqr um
				close(name+" Segmented");
				// ROIs of segmented particles are ready. We'll get the 'center of mass' for these.
			
				selectWindow(name);			roiManager("Deselect");			roiManager("Measure");		roiManager("reset");

// most of the detected maxima are slightly off-center. So trying to re-center them a bit.
// Using 'center of mass' instead of 'centroid' to identify the nucleus proper, as CoM takes into account the pixel intensity as well.
				base=8+5-floor((stage+1)/2);
				
// first loop is just establishing the baseline
				selectWindow(name);	
				x=Table.getColumn("XM");		y=Table.getColumn("YM");		run("Clear Results");
				for(coor=0; coor<x.length; coor++){
					xIter=x[coor];		yIter=y[coor];		toUnscaled(xIter, yIter);
					makeOval(xIter-base, yIter-base, base*2, base*2);		run("Measure");
				}
			}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// now we are actually trying to re-center
			selectWindow(name);			base=base+1;
			x=Table.getColumn("XM");		y=Table.getColumn("YM");		run("Clear Results");
			for(coor=0; coor<x.length; coor++){
				xIter=x[coor];		yIter=y[coor];		toUnscaled(xIter, yIter);
				makeOval(xIter-base, yIter-base, base*2, base*2);		run("Measure");
			}

// another loop to refine the re-centering
			selectWindow(name);			base=base+1;
			x=Table.getColumn("XM");		y=Table.getColumn("YM");		run("Clear Results");
			for(coor=0; coor<x.length; coor++){
				xIter=x[coor];		yIter=y[coor];		toUnscaled(xIter, yIter);
				makeOval(xIter-base, yIter-base, base*2, base*2);		run("Measure");
			}

// most of the detected maxima should be re-centered by now. In principle, we can increase the re-centering iterations
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
			selectWindow(name);		run("Select None");		run("Duplicate...", "title=["+name+" Maxima]");
			selectWindow(name+" Maxima");		run("Multiply...", "value=0");
	
			x=Table.getColumn("XM");		y=Table.getColumn("YM");		run("Clear Results");
			for(coor=0; coor<x.length; coor++){
				xIter=x[coor];		yIter=y[coor];		toUnscaled(xIter, yIter);
				makeOval(xIter-2, yIter-2, 4, 4);		run("Fill", "slice");
			}
// Maximas are painted on blank image. Now, we'll dilate them a bit
			run("8-bit");		run("Select None");		run("Gaussian Blur...", "sigma=1");		run("Red");
// this makes the auto-detected maxima look different from the manual correction	

// then, cleaning the edges
			getDimensions(width, height, channels, slices, frames);
			run("Canvas Size...", "width="+(width-10)+" height="+(height-10)+" position=Center");
			run("Canvas Size...", "width="+width+" height="+height+" position=Center zero");
		
			run("Merge Channels...", "c1=["+name+" Maxima] c4=["+name+"] create");

			if(stage==10 || stage==11){ //  IF statement for stage dependent contrast adjustment
				setSlice(2);		setMinAndMax(4, 200);		setSlice(1);
				
			}else{
				setSlice(2);		setMinAndMax(4, 400);		setSlice(1);
					
			} //  IF statement for stage dependent contrast adjustment
			
			Dialog.createNonBlocking("First quality control"); /// pause for manual input ///////////////////////////////////////////////
			Dialog.addMessage("Each nucleus should be marked");
			Dialog.addCheckbox("Yes?", false);
			Dialog.setLocation(dialogX,dialogY);
			Dialog.show();
			
			condition=Dialog.getCheckbox();

			if (condition==0){
				run("Split Channels");
				selectWindow("C1-Composite");		rename(name+" Maxima");		close(name+" Maxima"); // unnecessarilty explicit, but anyway 
				selectWindow("C2-Composite");		rename(name);
			}
		
		}while (condition==0) // loop to test different thresholds

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// finally adding a few manual touches, using paintbrush tool, to make sure that the segmentation is optimal.
// Ideally, the added touch-ups should be of different size, as compared to automated ones generated above.

	do{ // loop to manually correct the identified nuclei

		setTool("Paintbrush Tool");	// IJ.getToolName();		
		Dialog.createNonBlocking(""); /// pause for manual input ///////////////////////////////////////////////
		Dialog.addMessage("Pause to manually check and mark the nuclei\nuse the paintbrush to edit the nuclei segmentation");
		Dialog.setLocation(dialogX-60,dialogY);
		Dialog.show();
		
		run("Split Channels");

		selectWindow("C1-Composite");	
		setMetadata("Label", metadat);
		
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
		// note that the criterion is semi-objective

		run("Clear Results");		selectWindow(name);		roiManager("deselect");			roiManager("measure");
		
		deletion="";
		
		for (i=0; i<nResults; i++) { // FOR loop to filter out the outlier ROIs
			
			//if (getResult("Min", i)<10){ // any ROI that sticks out beyond the embryo is marked for deletion
			if (getResult("Min", i)<5){ // same as above, but with lower signal
				
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
		
		run("Merge Channels...", "c1=["+name+" Maxima] c4=["+name+"] create");		roiManager("Show All without labels");

		Dialog.createNonBlocking("Second quality control"); /// pause for manual input ///////////////////////////////////////////////
		Dialog.addMessage("The segmentation should isolate the nuclei");
		Dialog.addCheckbox("Yes?", false);
		Dialog.setLocation(dialogX,dialogY);
		Dialog.show();
		
		condition=Dialog.getCheckbox();

			if (condition==0){
				roiManager("reset");
			}else{
				run("Split Channels");
				selectWindow("C1-Composite");		rename(name+" Maxima");
				selectWindow("C2-Composite");		rename(name);
			}
			
		setTool("rectangle");
		
		}while (condition==0) // loop to manually correct the identified nuclei
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
		selectWindow(name+" Maxima");		roiManager("deselect");		run("Remove Overlay");		setMinAndMax(0, 255);
		save(folder+"/nuclear domain size analysis/Seeds_"+name+".tif");
		
		close("*"); // only thing remaining now is the ROIs in the manager
		
		roiManager("Save", folder+"/nuclear domain size analysis/Regions_"+name+"_old.zip");
		
// A preliminary segmentation is now ready. This will be refined below to remove outliers			
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

		open(folder+"/nuclear domain size analysis/MAX_"+name+".tif");		roiManager("deselect");		roiManager("measure");

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
			if (getResult("Mean",i)<mean_means/3 || getResult("Mean", i)>mean_means*3 || getResult("Area", i)<mean_areas/3 || getResult("Area", i)>mean_areas*3){
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

		roiManager("Save", folder+"/nuclear domain size analysis/Regions_"+name+".zip");					
		saveAs("Results", folder+"/nuclear domain size analysis/Data_"+name+".csv");

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
		roiManager("open", folder+"/nuclear domain size analysis/Regions_"+name+".zip");
		roiManager("Show All without labels");
		
		save(folder+"/nuclear domain size analysis/Nuclei_domains_"+name+".tif");

// saved a heat-map of areas
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		roiManager("reset");	run("Clear Results");	close("*");		run("Collect Garbage");
		
	} // IF statement to pick TIFF files

	file=file+1;
} while(file<files.length) // DO-WHILE loop through files 

exit();

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



