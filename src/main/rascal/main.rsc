module main

import lang::java::m3::Core;
import lang::java::m3::AST;

import type_2_baxter;
import utils;
import metrics;
import json_output;
import clones_to_txt;

int main(){
    str smallsql_name = "smallSQL";
    str hsql_name = "HSQL";
    str bench_name = "BenchmarkProject";

    loc smallsql_loc = |cwd:///smallsql0.21_src/|;
    loc hsql_loc = |cwd:///hsqldb-2.3.1/|;
    loc bench_loc = |cwd:///benchmarkProject/|;

    // -- Config Variables --
    int massThreshVal = 25;
    real simThresh = 1.0;
    int cloneType = 1;

    // call main project function with each location
    main_project_process(smallsql_loc, massThreshVal, simThresh, cloneType, smallsql_name);
    main_project_process(hsql_loc, massThreshVal, simThresh, cloneType, hsql_name);
    main_project_process(bench_loc, 10, simThresh, cloneType, bench_name); // smaller value for benchmark project since it's smaller


    return 0;
}

// idea: if type 2, run once with type 1. then run again with type 2. then a method compares the two and the second one is replaced
// with only the ones that weren't in type 1.

// second idea: if type 2, during the json output part, do string comparison (filtered for whitespace). if they're not the same string, then the clone class is type 2.
void main_project_process(loc project_loc, int massThresh, real simThresh, int cloneType, str name){
    // detect all clones and create clone classes
    list[Declaration] asts = getASTs(project_loc);
    set[set[loc]] allCloneClasses = baxtersAlgo(asts, massThresh, simThresh, cloneType);     

    // output clone metrics
    displayProjectMetrics(allCloneClasses, asts, name, cloneType);

    // write clone data to files
    clonesToJSON(name, cloneType, allCloneClasses);
    clonesToTxt(name, cloneType, allCloneClasses);
}