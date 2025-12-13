module main

import lang::java::m3::Core;
import lang::java::m3::AST;

import type_2_baxter;
import utils;
import metrics;
import json_output;

int main(){
    str smallsql_name = "smallSQL";
    str hsql_name = "HSQL";
    str bench_name = "BenchmarkProject";

    loc smallsql_loc = |cwd:///smallsql0.21_src/|;
    loc hsql_loc = |cwd:///hsqldb-2.3.1/|;
    loc bench_loc = |cwd:///benchmarkProject/|;

    // -- Config Variables --
    int massThreshVal = 15;
    real simThresh = 1.0;
    int cloneType = 2;

    // call main project function with each location
    // main_project_process(smallsql_loc, massThreshVal, simThresh, cloneType, smallsql_name);
    // main_project_process(hsql_loc, massThreshVal, simThresh, cloneType, hsql_name);
    main_project_process(bench_loc, massThreshVal, simThresh, cloneType, bench_name);


    return 0;
}

void main_project_process(loc project_loc, int massThresh, real simThresh, int cloneType, str name){
    // detect all clones and create clone classes
    list[Declaration] asts = getASTs(project_loc);
    set[set[loc]] allCloneClasses = baxtersAlgo(asts, massThresh, simThresh, cloneType);

    // output clone metrics
    displayProjectMetrics(allCloneClasses, asts, name, cloneType);

    // write clone data to json file
    clonesToJSON(name, cloneType, allCloneClasses);
}