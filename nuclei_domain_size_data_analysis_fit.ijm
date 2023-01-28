// This macro prepare the data to be fitted with parabola in the graphpad Prism. The choice of arranging the data and the format of the 
// output is chosen to facilitate a simple copy-paste(transpose) data input.

//run("Set Measurements...", "area mean centroid center redirect=None decimal=6");
//run("Set Measurements...", "area centroid perimeter shape redirect=None decimal=6");
run("Set Measurements...", "area mean standard centroid center perimeter shape redirect=None decimal=6");

print("\\Clear");
numPaths=getNumber("Number of repeats =", 5); // This should be the number of days at a given temperature

paths=newArray(numPaths);

for (path=0; path<numPaths; path++) {
	paths[path]=getDirectory("Choose a folder with all data from the day"); // this should will be named 'yyyymmdd (temperature)'
	print(paths[path]); // not really necessary. Just helps keep track of the selections so far
}

data_print="";		print("\\Clear");		run("Clear Results"); // clean slate

stages=newArray("inter-10","inter-11","inter-12","inter-13","inter-14");

for(stage=0; stage<stages.length; stage++){ // FOR loop to open together files of the same stage
	
	data_print=data_print+"\nInterphase_"+(stage+10)+"\n"; // write down the interphase of interest
	
	// (re)set all major variables for the same interphase
	daysCounter=0;		embryo=0;		nAreas=0;		data_print_x="X";		data_print_y="Y";		data_print_areas="";
	
	do{ // DO-WHILE loop over days of experiments
		
		parent=paths[daysCounter];		
		date=File.getName(parent); //'date' is the name of the folder (to be included later on)
		target=File.getParent(parent); //'target' is the folder location where the final output will be saved
		// Of note, the 'target' is redefined all the time. But, the identity of the directory is always the same.
		
		folder=parent+"/interphase nuclei count/nuclear domain size analysis/";		files=getFileList(folder);
		
		file=0;
		do{ // DO-WHILE loop through files, to now write the data
			existance=indexOf(files[file],stages[stage]);
			
			if (endsWith(files[file],".csv") && existance>0) { // IF statement to pick CSV files of specific stage
				open(folder+files[file]);		name=File.nameWithoutExtension;
				
				embryoName=substring(name,indexOf(name,"Dme_")+4,indexOf(name,"inter")-1); // w/o the underscore before 'inter'
				timepoint=substring(name,indexOf(name,"inter")+8); // including the underscore before 't'
				
				areas=Table.getColumn("Area");		xCoor=Table.getColumn("XM");		yCoor=Table.getColumn("YM");	run("Clear Results");
				
				data_print_x=data_print_x+" ,";		data_print_y=data_print_y+" ,"; // the spacer between two embryos
				
				for (i=0; i<xCoor.length; i++) {
					data_print_x=data_print_x+","+xCoor[i]; // writing the x-coordinate (in micron)
				}

				for (i=0; i<yCoor.length; i++) {
					data_print_y=data_print_y+","+yCoor[i]; // writing the y-coordinate (in micron)
				}
				
				data_print_areas=data_print_areas+date+"_"+embryoName+timepoint+",";
				// this way, the label includes the date, temperature, the identity of the embryo, and the timepoint
				
				if (embryo>0){
					for (i=0; i<nAreas; i++) { // Adding extra leading spaces, in case the embryo is not the first one
						data_print_areas=data_print_areas+" ,";
					}
				}
				
				nAreas=nAreas+areas.length+1; // the '+1' would work as the spacer between two embryos
				
				for (i=0; i<areas.length; i++) {
					data_print_areas=data_print_areas+","+areas[i]; // now writing the area (in square-micron)
				}
				
				data_print_areas=data_print_areas+"\n";
				
				close(files[file]);		embryo=embryo+1;
			} // IF statement to pick CSV files of specific stage
			
			file=file+1;
		}while(file<files.length) // DO-WHILE loop through files, to now write the data
		
		daysCounter=daysCounter+1;
	}while (daysCounter<paths.length) // DO-WHILE loop over days of experiments
	
	data_print=data_print+data_print_x+"\n"+data_print_y+"\n"+data_print_areas;
	
} // FOR loop to open together files of the same stage

print(data_print);

//target=getDirectory("Choose a folder to save the data");

selectWindow("Log");
saveAs("Text...",target+"/nuclear_domains_fit.csv");

exit();
//////////////////////////////////////////////////// end of the code //////////////////////////////////////////////////////////////////////////////