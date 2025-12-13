module utils

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;

import IO;
import List;
import Set;
import String;
import ParseTree;

// ====================filtering functions built for this project====================
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

node type2CloneASTFiltering(node subtree){
    return visit(subtree) {
    
    // expressions
     case \characterLiteral(str charValue) => \characterLiteral("charVal")
     case \number(str numberValue) => \number("numVal")
     case \booleanLiteral(str boolValue) => \booleanLiteral("boolVal")
     case \stringLiteral(str stringValue) => \stringLiteral("strVal")
     case \textBlock(str stringValue) => \textBlock("txtBlcVal")
     case \id(str identifier) => \id("identifier")
    }
}

// full processing for removing whitespace and comments
str type_1_filter(str file){
    str initial_filtering = removeMultiLineComments(file);
    str final_result = "";
    list[str] lines = split("\n", initial_filtering);
    for(line <- lines){
        if(line != ""){ // filter out empty lines
            final_result = final_result + removeWhitespace(removeLineComments(line)) + "\n";
        }
    }
    return final_result[0..-2]; // get rid of the final newline
}

str removeLineComments(str line) {
    bool inString = false;
    bool escaped = false;
    
    for (int i <- [0..size(line)-1]) {
        if (escaped) {
            escaped = false;
            continue;
        }
        
        if (line[i] == "\\") {
            escaped = true;
            continue;
        }
        
        if (line[i] == "\"") {
            inString = !inString;
        }
        
        // Found // outside of a string
        if (!inString && i < size(line)-1 && line[i] == "/" && line[i+1] == "/") {
            return line[0..i];
        }
    }
    return line;
}

// might need to revise to look for escaped versions of the block comment indicators (like in a string)
str removeMultiLineComments(str file){
    return visit(file) {
        case /\/\*.*?\*\//s => ""
    };
}

str removeWhitespace(str line){
    return visit (line) {
                case /[\t\n]/ => ""
                };
}
// ====================class provided functions====================
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

// ====================reused functions from series 1====================
int countLOC(str source) {
    return (0 | it + 1 | /\n/ := source);
}

// ====================new custom data types====================
data ClonePair = clonePair(loc first_file, loc second_file);