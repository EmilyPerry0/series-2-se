module clones_to_txt

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import Set;

void clonesToTxt(str name,int cloneType,set[set[loc]] allCloneClasses){
    list[str] linesToWrite = ["Project Name: <name>", "Maximum Clone Type: <cloneType>", "===================="];
    str cloneType_str = "<cloneType>";
    loc output_loc = |cwd:///TextualOutput/<name>Type<cloneType_str>.txt|;
    int i = 1;
    for(class <- allCloneClasses){
        linesToWrite = linesToWrite + "Clone Class <i>";
        for(clone <- class){
            linesToWrite = linesToWrite + "<clone>";
        }
        i += 1;
        linesToWrite = linesToWrite + "====================";
    }
    writeFileLines(output_loc, linesToWrite);
}