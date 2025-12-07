module series_2

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;

import IO;
import List;
import Set;
import String;
import ParseTree;

int main() {
    loc smallsql_loc = |cwd:///smallsql0.21_src/|;
    loc hsql_loc = |cwd:///hsqldb-2.3.1/|;
    getAllClonePairs(hsql_loc);
    // list[Declaration] asts = getASTs(hsql_loc);
    return 0;
}

// return type should not be int
// for now, clone pairs will be 3 lines long, but in the final implementation, they should be from 1 to file length i think
int getAllClonePairs(loc projectLocation){
    list[loc] javaFiles = getAllJavaFiles(projectLocation);
    // loop over the files and search for duplicates of each lines
    for (loc f <- javaFiles){
        str src = readFile(f);
        src = removeMultiLineComments(src);
        list[str] lines = split("\n", src);
        // filter out comments
        for(str line <- lines){
            removeWhitespace(line);
            if(size(line) > 0){
                str filtered_str = removeLineComments(line);
                println(filtered_str); // TODO: actually use the filtered lines to check for clones
            }
        }
    }
    return 0;
}

data ClonePair = clonePair(loc first_file, loc second_file, tuple[int, int] first_line_nums, tuple[int, int] second_line_nums);



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
// ========================functions from series 1===========================

list[loc] getAllJavaFiles(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    return [f | f <- files(model.containment), isCompilationUnit(f)];
}

int getLOCfromMethod(str method){
    return (0 | it + 1 | /\n/ := method);
}

list[str] getAllMethods(loc projectLocation){
    M3 model = createM3FromMavenProject(projectLocation);
    list[loc] methodLocations = toList(methods(model));
    list[str] methodsSourceCode = [];
    for (n <- methodLocations){
        methodsSourceCode = push(readFile(n), methodsSourceCode);
    }
    return methodsSourceCode;
}

// class provided function
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}