/*  Works on ImageJ 1.53c / Windows
 *  Created in february 2022 by David Remy

 *  This macro quantifies the mean intensity per cell of a given channel.
 *  Batch quantification included: input should be a folder containing all acquisitions from one experimental condition
 *  
 */
 
 

// Clears everything
roiManager("reset");
run("Clear Results");
run("Close All");
setOption("ExpandableArrays", true); // In ImageJ 1.53g and later, arrays automatically expand in size as needed. This option is used in case of early versions of ImageJ
if( isOpen("Summary") ){
	selectWindow("Summary");
	run("Close");
}
run("Set Measurements...", "area mean standard modal min centroid integrated area_fraction redirect=None decimal=3");
/////////////////////////////////////////////////////////////
////// begining of parameters customozible by the user //////
/////////////////////////////////////////////////////////////
// extensions of the file to study
ext= ".tif";
// size of the rolling ball in pixels for the substract bg of the channel of interest - it is recommended to test this parameter on several images before deciding on one value
rolling_ball_param_int = 10;
/////////////////////////////////////////////////////////////
//////// end of parameters customozible by the user /////////
/////////////////////////////////////////////////////////////
 

// Dialog box for channel number/name assignment 
channels_choice=newArray(1, 2, 3, 4);
Dialog.create("Channels of interest");
Dialog.addMessage("1: DAPI ; 2:GFP ; 3: Cy3; 4: Cy5"); 
Dialog.addChoice("Which channel for cell mask", channels_choice, "4.0");
Dialog.addChoice("Which channel for intensity measurement", channels_choice, "2.0");
Dialog.addString("Name of the target ?", "");
Dialog.addCheckbox("If z-stack, Max Projection on the entire z-stack ?" , true);
Dialog.show();

Mask_channel=Dialog.getChoice();
Inten_channel=Dialog.getChoice();
protein=Dialog.getString();
proj=Dialog.getCheckbox();

// Select input directory and create an Analysis subfolder
dir_input=getDirectory("Select input directory");
if( !File.exists(dir_input+protein+"_IntensityAnalysis") ) { // creates directory if does not exist
	File.makeDirectory(dir_input+protein+"_IntensityAnalysis");
}
dir_output=dir_input+protein+"_IntensityAnalysis"+File.separator; 
//Give a table with every files names within the directory
Filelist=getFileList(dir_input);
Array.sort(Filelist);

Acqui=newArray();
Intensity=newArray();

file_treated = 0;
for (i_file=0; i_file<lengthOf(Filelist); i_file++) {
	if(indexOf(Filelist[i_file], ext) >0 ){ 
		shortTitle = substring(Filelist[i_file],0,lastIndexOf(Filelist[i_file],"."));
			
		// opens and rescales image
		run("Bio-Formats Importer", "open=["+dir_input+Filelist[i_file]+"] autoscale color_mode=Default open_files view=Hyperstack stack_order=XYCZT");
		tit_img = getTitle();
		run("Set Scale...", "distance=1");
		getDimensions(width, height, channels, slices, frames);
		first_plan = 1;
		last_plan = nSlices;
		
		// check that the specified channels exist
		if( channels < maxOf(Mask_channel,Inten_channel) ) {
			print("Image "+Filelist[i_file]+" not treated: at least one of the specified channel do not exist");
		}
		
		else{
			print("Treating image "+Filelist[i_file]);
		}
		
		if( !File.exists(dir_output+"Results_"+shortTitle+".xls") ){ // the image was not treated
			// duplicates the channels of interest	
			selectWindow(Filelist[i_file]);
			run("Duplicate...", "title=mask duplicate channels="+Mask_channel);
			selectWindow(Filelist[i_file]);
			run("Duplicate...", "title="+protein+" duplicate channels="+Inten_channel);
		
			// Determine the z plans if you want to select a few slices only 
			selectWindow("mask");
			// image is a stack and the user asked to choose the plans of analysis
			if( nSlices > 1 && !proj) {
	
				Dialog.createNonBlocking("Plans choice");
				Dialog.addMessage("Choose the plan to analyze, between 1 and "+slices+" (put the same value if you want only one image)."); 
				Dialog.addMessage("If several plans, a projection will be performed.");
				Dialog.addNumber("First plan (above 1)", 1);
				Dialog.addNumber("Last Plan (below "+slices+")", slices);
				Dialog.show();
			
				first_plan = Dialog.getNumber();
				last_plan = Dialog.getNumber();
				
				if( first_plan < 1 || first_plan > slices || last_plan < 1 || last_plan > slices)
					exit("You choose an uncorrect number of plan");
	
				selectWindow("mask");
				run("Z Project...", "start="+first_plan+" stop="+last_plan+" projection=[Max Intensity]");
				close("mask");
			}
			// Max Projection on all the stack if you chose that option 
			if( nSlices > 1 && proj) {
				run("Z Project...", "start="+first_plan+" stop="+last_plan+" projection=[Max Intensity]");
			}
		
			else {
				rename("MAX_mask");
			}
			
			// Select cell(s) shape(s)
			selectWindow("MAX_mask");
			run("Enhance Contrast", "saturated=0.35");
			run("Enhance Contrast", "saturated=0.35");
			setTool(3);
			
			if (File.exists(dir_output+shortTitle+"_CellROIs.zip")) {
				roiManager("open", dir_output+shortTitle+"_CellROIs.zip");
				selectWindow("MAX_mask");
				waitForUser("Draw additionnal cells and add to ROI Manager if required");
			}
			
			else { // if no ROI file: the user draw the cells
				while (roiManager("count")<1) {
					selectWindow("MAX_mask");
					waitForUser("Draw cell and add to ROI Manager");
				}
			}
			
			roiManager("deselect");
			roiManager("save", dir_output+shortTitle+"_CellROIs.zip");
			nbCells = roiManager("count");
			// tables that will contain result for THIS acquisition 
			PictureName=newArray(nbCells);
			MeanInt=newArray(nbCells);
			
			// Pre-processing of the target channel and intensity measurement
			selectWindow(protein);
			
			// image is a stack and the user asked to choose the plans of analysis
			if( nSlices > 1 && !proj) {
				run("Z Project...", "start="+first_plan+" stop="+last_plan+" projection=[Max Intensity]");
				close(protein);
			}
			// Max Projection on all the stack if you chose that option 
			if( nSlices > 1 && proj) {
				run("Z Project...", "start="+first_plan+" stop="+last_plan+" projection=[Max Intensity]");
			}
		
			else {
				rename("MAX_"+protein);
			}
			
			selectWindow("MAX_"+protein);
			run("Subtract Background...", "rolling="+rolling_ball_param_int);
			roiManager("deselect");
			roiManager("measure");
			
			for (j = 0; j < nResults; j++) {
				PictureName[j]=shortTitle+"_Cell_"+j+1 ;
				MeanInt[j]=getResult("Mean", j);
			}
			run("Clear Results");
			roiManager("reset");
			close("*");
		}
		
		else{ // the image was aready treated: we load the results
			print("Results file existed: loaded");
			run("Results... ","open=["+dir_output+"Results_"+shortTitle+".xls]");
			Acqui[file_treated]=shortTitle;
			Intensity[file_treated] = getResult("Mean Intensity of "+protein, 0);
			file_treated++;
			close("Results");
		}
	}
	
	else {
		continue
	}
		
	Acqui=Array.concat(Acqui,PictureName);
	Intensity=Array.concat(Intensity,MeanInt);	
}

run("Clear Results");
for (i_results = 0; i_results < lengthOf(Acqui); i_results++) {
	setResult("Cell name", i_results, Acqui[i_results]);
	setResult("Mean Intensity of "+protein, i_results, Intensity[i_results]);
}

saveAs("Results", dir_output+protein+"_MeanIntensity.xls");