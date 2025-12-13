module metrics

import lang::java::m3::Core;
import lang::java::m3::AST;

import IO;
import Set;
import utils;
import String;
import List;

void displayProjectMetrics(set[set[loc]] cloneClasses, list[Declaration] asts, str projectName, int cloneType){
    // calculate metrics
    int clonedLOC = getTotalLOCFromAllClones(cloneClasses);
    int totalLOC = getProjectLOCFromASTs(asts);
    real duplicatedPercent = 100.0 * clonedLOC / totalLOC;
    int biggestCloneSize = getBiggestCloneSize(cloneClasses);
    int biggestCloneClass = getBiggestCloneClass(cloneClasses);
    int numClones = calcNumClones(cloneClasses);

    list[ClonePair] exampleClones = getExampleClones(cloneClasses);
    
    // display metrics
    println("Summary Report:");
    println("Project: <projectName>");
    println("Clone Type <cloneType>");
    println("Duplicated Line %: <duplicatedPercent>%");
    println("Number of Clones: <numClones>");
    println("Biggest Clone: <biggestCloneSize> LOC");
    println("Biggest Clone Class: <biggestCloneClass> Members");
    println("Some Example Clones: ");
    for(i <- [0,1]){
        println("=====Example <i+1>=====");
        println("Location 1: <exampleClones[i].first_file>");
        println("Location 2: <exampleClones[i].second_file>");
        println("File 1:");
        loc first_file_example = exampleClones[i].first_file;
        str first_str_example = readFile(first_file_example);
        println(first_str_example);
        println("File 2:");
        loc second_file_example = exampleClones[i].second_file;
        str second_str_example = readFile(second_file_example);
        println(second_str_example);
    }
}

int getBiggestCloneClass(set[set[loc]] cloneClasses){
    int maxSize = -1;

    for(class <- cloneClasses){
        if(size(class) > maxSize){
            maxSize = size(class);
        }
    }
    return maxSize;
}

int getBiggestCloneSize(set[set[loc]] allCloneClasses){
    int maxSize = -1;
    int currSize = -1;

    for(cloneClass <- allCloneClasses){
        currSize = getLOCfromCloneClass(cloneClass);
        if(currSize > maxSize){
            maxSize = currSize;
        }
    }
    return maxSize;
}

int getProjectLOCFromASTs(list[Declaration] asts){
    set[loc] uniqueFiles = {ast.src.top | ast <- asts};
    str currFile = "";
    str filteredFile = "";
    int total = 0;
    
    for(file <- uniqueFiles){
        currFile = readFile(file);
        filteredFile = type_1_filter(currFile);
        total += countLOC(filteredFile);
    }
    return total;
}

int getTotalLOCFromAllClones(set[set[loc]] allClasses){
    int total = 0;
    for(class <- allClasses){
        total += getLOCfromCloneClass(class);
    }
    return total;
}

int getLOCfromCloneClass(set[loc] class){
    int total = 0;
    for(clone <- class){
        str lines = type_1_filter(readFile(clone));
        total += size(split("\n", lines));
    }
    return total;
}

int calcNumClones(set[set[loc]] allcloneClasses){
    int total = 0;
    for(cloneClass <- allcloneClasses){
        for(clone <- cloneClass){
            total += 1;
        }
    }
    return total;
}

list[ClonePair] getExampleClones(set[set[loc]] allCloneClasses){
    list[set[loc]] list_allCloneClasses = toList(allCloneClasses);
    list[loc] firstExampleClass = toList(list_allCloneClasses[0]);
    list[loc] secondExampleClass = toList(list_allCloneClasses[1]);

    ClonePair firstExample = clonePair(firstExampleClass[0], firstExampleClass[1]);
    ClonePair secondExample = clonePair(secondExampleClass[0], secondExampleClass[1]);

    return [firstExample, secondExample];
}