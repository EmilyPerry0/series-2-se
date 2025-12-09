module type_2_clones

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;

import IO;

import utils;

/*
The algorithm consists of the following steps:
1. parse program and generate AST
2. serialize AST
3. apply suffix tree detection
4. decompose resulting type-1/type-2 token sequence into complete syntactic units
*/

int main(){
    loc smallsql_loc = |cwd:///smallsql0.21_src/|;
    loc hsql_loc = |cwd:///hsqldb-2.3.1/|;
    list[Declaration] asts = getASTs(smallsql_loc); // step1: parse program and generate AST
    Declaration seriazlied_ast = serializeAST(asts[5]);
    println(seriazlied_ast);
    return 0;
}

// step 2: serialize AST
// We serialize the AST by a preorder traversal
Declaration serializeAST(Declaration ast){
    return visit(ast) {
    
    // expressions
     case \assignment(Expression lhs, str operator, Expression rhs) => \assignment(lhs, "=", rhs)
     case \characterLiteral(str charValue) => \characterLiteral("charVal")
     case \fieldAccess(Expression name) => \fieldAccess(\id("fieldAccess"))
     case \fieldAccess(Expression qualifier, Expression name) => \fieldAccess(qualifier, \id("fieldAccess"))
     case \superFieldAccess(Expression expression, Expression name) => superFieldAccess(expression, \id("superFieldAccess"))
     case \methodCall(list[Type] typeArguments, Expression name, list[Expression] arguments) => \methodCall(typeArguments, \id("methodCall"), arguments)
     case \methodCall(Expression receiver, list[Type] typeArguments, Expression name, list[Expression] arguments) => methodCall(receiver, typeArguments, \id("methodCall"), arguments)
     case \superMethodCall(list[Type] typeArguments, Expression name, list[Expression] arguments) => \superMethodCall(typeArguments, \id("superMethodCall"), arguments)
     case \superMethodCall(Expression qualifier, list[Type] typeArguments, Expression name, list[Expression] arguments) => superMethodCall(qualifier, typeArguments, \id("superMethodCall"), arguments)
     case \number(str numberValue) => \number("numVal")
     case \booleanLiteral(str boolValue) => \booleanLiteral("boolVal")
     case \stringLiteral(str stringValue) => \stringLiteral("strVal")
     case \stringLiteral(str stringValue, str literal) => \stringLiteral("strVal", "strVal")
     case \textBlock(str stringValue) => \textBlock("txtBlcVal")
     case \textBlock(str stringValue, str literal) => \textBlock("txtBlcVal", "txtBlcVal")
    //  case \id(str identifier) // not 100% sure about this one
     case \methodReference(Type \type, list[Type] typeArguments, Expression name) => \methodReference(\type, typeArguments,\id("methodRef"))
     case \methodReference(Expression expression, list[Type] typeArguments, Expression name) => \methodRef(expression, typeArguments, \id("methodRef"))
     case \superMethodReference(list[Type] typeArguments, Expression name) => \superMethodReference(typeArguments,\id("superMethodRef"))
     case \memberValuePair(Expression name, Expression \value) => \memberValuePair(\id("memValPair"),\value)
    }
}

void old_serializeAST(Declaration ast){
    str result = "";
    visit(ast) {
        case \if(_,_) : result += "if";
        case \if(_,_,_) : result += "if";
        case \for(_,_,_) : result += "for";
    }
    println(result);
}

// helpful guide for visit
int calcCC(Declaration impl) {
    int result = 1;
    visit (impl) {
        case \if(_,_) : result += 1;
        case \if(_,_,_) : result += 1;
        case \case(_) : result += 1;
        case \do(_,_) : result += 1;
        case \while(_,_) : result += 1;
        case \for(_,_,_) : result += 1;
        case \for(_,_,_,_) : result += 1;
        case \foreach(_,_,_) : result += 1;
        case \catch(_,_): result += 1;
        case \conditional(_,_,_): result += 1;
        // case \infix(_,"&&",_) : result += 1;
        // case \infix(_,"||",_) : result += 1;
    }
    return result;
}