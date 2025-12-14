module clones_to_txt

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import Set;
import utils;

void clonesToTxt(str name,int cloneType,set[set[loc]] allCloneClasses){
    list[str] linesToWriteType1 = ["Project Name: <name>", "Clone Type: 1", "===================="];
    list[str] linesToWriteType2 = ["Project Name: <name>", "Clone Type: 2", "===================="];
    str cloneTypeStr = "<cloneType>";
    loc output_loc_1 = |cwd:///TextualOutput/<name>Type1.txt|;
    loc output_loc_2 = |cwd:///TextualOutput/<name>Type2.txt|;
    int type1Count = 1;
    int type2Count = 1;

    for(class <- allCloneClasses){
        bool type2 = false;

        if(cloneType == 2){
            cloneTypeStr = "2";
            for(memberLoc <- class){
                if(type2){
                    break;
                }
                for(memberLocComp <- class){
                    if(memberLoc == memberLocComp){continue;}
                    if(type_1_filter(readFile(memberLoc)) != type_1_filter(readFile(memberLocComp))){
                        type2 = true;
                        break;
                    }
                }
            }
            if(!type2){
                cloneTypeStr = "1";
            }
        }

        if(cloneTypeStr == "1"){
            linesToWriteType1 = linesToWriteType1 + "Clone Class <type1Count>";
            for(clone <- class){
                linesToWriteType1 = linesToWriteType1 + "<clone>";
            }
            type1Count += 1;
            linesToWriteType1 = linesToWriteType1 + "====================";
        }else{
            linesToWriteType2 = linesToWriteType2 + "Clone Class <type2Count>";
            for(clone <- class){
                linesToWriteType2 = linesToWriteType2 + "<clone>";
            }
            type2Count += 1;
            linesToWriteType2 = linesToWriteType2 + "====================";
        }
    }
    if(cloneType == 2){
        writeFileLines(output_loc_1, linesToWriteType1);
        writeFileLines(output_loc_2, linesToWriteType2);
    }else{
        writeFileLines(output_loc_1, linesToWriteType1);
    }
}