//run("Set Measurements...", "area mean centroid center redirect=None decimal=6");
//run("Set Measurements...", "area centroid perimeter shape redirect=None decimal=6");
run("Set Measurements...", "area mean standard centroid center perimeter shape integrated redirect=None decimal=6");		

inf=0;
do{ // an infinite DO...WHILE loop
	
parent=getDirectory("Choose a folder with embryo images"); // this should be the folder 'interphase nuclei count'

target=File.getParent(parent);		//'target' is the folder location
date=File.getName(target);			//'date' is the name of the 'target' folder

folder=parent+"/nuclear domain size analysis/";
files=getFileList(parent);

data_print="";		print("\\Clear");		run("Clear Results");

stages=newArray("inter-10","inter-11","inter-12","inter-13","inter-14");

for(stage=0; stage<stages.length; stage++){ // FOR loop to open together files of the same stage
	data_print=data_print+"\nInterphase_"+(stage+10);

	file=0;		
	do{ // DO-WHILE loop through files 
		existance=indexOf(files[file],stages[stage]);

		if (existance>0) { // IF statement to pick CSV files of specific stage
			
			open(folder+"Nuclei_domains_"+files[file]);		

			run("Remove Overlay");		run("32-bit");

			setAutoThreshold("Default dark");
			//run("Threshold...");
			setThreshold(1.0000, 1000000000000000000000000000000.0000);
			setOption("BlackBackground", true);
			run("Convert to Mask");
			
			run("Options...", "iterations=1 count=1 black do=Close");
			run("Options...", "iterations=1 count=1 black do=[Fill Holes]");

			roiManager("reset");		run("Analyze Particles...", "size=40-Infinity pixel add");

			close("Nuclei_domains_*");

			open(folder+"Seeds_"+files[file]);			name=File.nameWithoutExtension;

			run("Find Maxima...", "prominence=150 exclude output=[Single Points]");		close(name);
			selectWindow(name+".tif Maxima");		rename(name);
			
			selectWindow(name);				run("Divide...", "value=255");

			if(roiManager("count")>1){
				roiManager("deselect");		roiManager("combine");		run("Measure");		close(name);
			}else{
				roiManager("select",0);		run("Measure");		close(name);
			}

			name=substring(name, indexOf(name, "Seeds_")+6);
			
			areaNuclei=getResult("Area");		numNuclei=getResult("RawIntDen");

			roiManager("Save", folder+"/Regions_"+name+"_combined.zip");

			roiManager("reset");	run("Clear Results");

			
			embryoName=substring(name,indexOf(name,"Dme_")+4,indexOf(name,"inter")-1); // w/o the underscore before 'inter'
			timepoint=substring(name,indexOf(name,"inter")+8); // includin the underscore before 't'
	
			data_print=data_print+"\n"+date+"_"+embryoName+timepoint+"\n";
			
			data_print=data_print+(areaNuclei/numNuclei)+", ,"+areaNuclei+","+numNuclei;

			close("*");
		} // IF statement to pick CSV files of specific stage
	
		file=file+1;
	}while(file<files.length) // DO-WHILE loop through files 
	
	data_print=data_print+"\n";
} // FOR loop to open together files of the same stage

print(data_print);
selectWindow("Log");
//
saveAs("Text...",target+"/"+date+"_nuclear_domains_course.csv");
//saveAs("Text...",target+"/"+date+"_"+embryoName+"_nuclear_domains.xls");

}while (inf==0) // an infinite DO...WHILE loop

exit();
//////////////////////////////////////////////////// end of the code //////////////////////////////////////////////////////////////////////////////