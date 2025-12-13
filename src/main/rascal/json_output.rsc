module json_output

import lang::json::IO;
import lang::java::m3::Core;
import lang::java::m3::AST;

void clonesToJSON(str projectName, int cloneType, set[set[loc]] cloneClasses){
    map[str, value] jsonOutput = generateJsonOutput(projectName, cloneType, cloneClasses);
    loc output_loc = |cwd:///data/<projectName>.json|;
    writeJSON(output_loc, jsonOutput);
}

map[str, value] generateJsonOutput(str projectName, int cloneType,set[set[loc]] cloneClasses) {
    tuple[map[str, int], list[tuple[int, str]]] fileData = collectFileInfos(cloneClasses);
    map[str, int] pathToId = fileData[0];
    list[tuple[int, str]] fileList = fileData[1];
    
    list[map[str, value]] jsonFiles = [];
    for (<id, path> <- fileList) {
        // Create the "files" array structure
        jsonFiles += ("id": id, "path": path);
    }
    
    // 2. Process clone classes
    list[map[str, value]] jsonCloneClasses = [];
    int classId = 1;
    
    str cloneTypeStr = "Type<cloneType>";
    
    for (cloneClass <- cloneClasses) {
        list[map[str, value]] membersJson = [];
        
        for (loc memberLoc <- cloneClass) {
            str filePath = memberLoc.path;
            int fileId = pathToId[filePath];
            
            CloneMember member = createCloneMember(memberLoc, fileId);
            
            // Convert CloneMember record to JSON-compatible map
            membersJson += (
                "fileId": member.fileId,
                "beginLine": member.beginLine,
                "endLine": member.endLine,
                "beginCol": member.beginCol,
                "endCol": member.endCol
            );
        }
        
        // Convert CloneClassJson record to JSON-compatible map
        jsonCloneClasses += (
            "id": classId,
            "type": cloneTypeStr,
            "members": membersJson
        );
        
        classId += 1;
    }
    
    // 3. Assemble the final structure
    map[str, value] finalJsonStructure = (
        "project": projectName,
        "files": jsonFiles,
        "cloneClasses": jsonCloneClasses
    );
    
    return finalJsonStructure;
}

tuple[map[str, int], list[tuple[int, str]]] collectFileInfos(set[set[loc]] cloneClasses) {
    map[str, int] pathToId = ();
    int nextId = 0;
    
    // Extract unique file paths from all clone classes
    set[str] uniquePaths = {l.path | set[loc] cc <- cloneClasses, loc l <- cc};
    
    list[tuple[int, str]] fileList = [];
    
    for (str path <- uniquePaths) {
        pathToId[path] = nextId;
        fileList += [<nextId, path>];
        nextId += 1;
    }
    
    return <pathToId, fileList>;
}

CloneMember createCloneMember(loc cloneLoc, int fileId) {
    
    return cloneMember(
        fileId,
        cloneLoc.begin.line, 
        cloneLoc.end.line,
        cloneLoc.begin.column + 1,
        cloneLoc.end.column + 1
    );
}

data CloneMember = cloneMember(
    int fileId, 
    int beginLine, 
    int endLine, 
    int beginCol, 
    int endCol
);