//run("Set Measurements...", "area mean centroid center redirect=None decimal=6");
//run("Set Measurements...", "area centroid perimeter shape redirect=None decimal=6");
run("Set Measurements...", "area mean standard centroid center perimeter shape redirect=None decimal=6");			

inf=0;
do{ // an infinite DO...WHILE loop
	
parent=getDirectory("Choose a folder with embryo images"); // this should be the folder 'interphase nuclei count'

target=File.getParent(parent);		//'target' is the folder location
date=File.getName(target);			//'date' is the name of the 'target' folder

folder=parent+"/nuclear domain size analysis/";
files=getFileList(folder);

data_print="";		print("\\Clear");		run("Clear Results");

stages=newArray("inter-10","inter-11","inter-12","inter-13","inter-14");

for(stage=0; stage<stages.length; stage++){ // FOR loop to open together files of the same stage
	data_print=data_print+"\nInterphase_"+(stage+10);

	file=0;		
	do{ // DO-WHILE loop through files 
		existance=indexOf(files[file],stages[stage]);

		if (endsWith(files[file],".csv") && existance>0) { // IF statement to pick CSV files of specific stage
			open(folder+files[file]);		name=File.nameWithoutExtension;
			
			embryoName=substring(name,indexOf(name,"Dme_")+4,indexOf(name,"inter")-1); // w/o the underscore before 'inter'
			timepoint=substring(name,indexOf(name,"inter")+8); // includin the underscore before 't'
			
			areas=Table.getColumn("Area");		run("Clear Results");
	
			data_print=data_print+"\n"+date+"_"+embryoName+timepoint+"\n"+areas[0];
			
			for (i=1; i<areas.length; i++) {
				data_print=data_print+","+areas[i];
			}

			close(files[file]);
		} // IF statement to pick CSV files of specific stage
	
		file=file+1;
	}while(file<files.length) // DO-WHILE loop through files 
	
	data_print=data_print+"\n";
} // FOR loop to open together files of the same stage

print(data_print);
selectWindow("Log");
saveAs("Text...",target+"/"+date+"_nuclear_domains_fine.csv");
//saveAs("Text...",target+"/"+date+"_"+embryoName+"_nuclear_domains.xls");

}while (inf==0) // an infinite DO...WHILE loop

exit();
//////////////////////////////////////////////////// end of the code //////////////////////////////////////////////////////////////////////////////