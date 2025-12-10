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
Declaration type2CloneASTFiltering(Declaration ast){
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
     case \textBlock(str stringValue) => \textBlock("txtBlcVal")
    //  case \id(str identifier) // not 100% sure about this one
     case \methodReference(Type \type, list[Type] typeArguments, Expression name) => \methodReference(\type, typeArguments,\id("methodRef"))
     case \methodReference(Expression expression, list[Type] typeArguments, Expression name) => \methodReference(expression, typeArguments, \id("methodRef"))
     case \superMethodReference(list[Type] typeArguments, Expression name) => \superMethodReference(typeArguments,\id("superMethodRef"))
     case \memberValuePair(Expression name, Expression \value) => \memberValuePair(\id("memValPair"),\value)

     //Declarations
     case  \enum(list[Modifier] modifiers, Expression name, list[Type] implements, list[Declaration] constants, list[Declaration] body) => \enum(modifiers, \id("enum"), implements, constants, body)
     case  \enumConstant(list[Modifier] modifiers, Expression name, list[Expression] arguments, Declaration class) => \enumConstant(modifiers, \id("enumConstant"), arguments, class)
     case  \enumConstant(list[Modifier] modifiers, Expression name, list[Expression] arguments) => \enumConstant(modifiers, \id("enumConstant"), arguments)
     case  \class(list[Modifier] modifiers, Expression name, list[Declaration] typeParameters, list[Type] extends, list[Type] implements, list[Declaration] body) => \class(modifiers, \id("class"), typeParameters, extends, implements, body)
     case  \interface(list[Modifier] modifiers, Expression name, list[Declaration] typeParameters, list[Type] extends, list[Type] implements, list[Declaration] body) => \interface(modifiers, \id("interface"), typeParameters, extends, implements, body)
     case  \method(list[Modifier] modifiers, list[Declaration] typeParameters, Type \return, Expression name, list[Declaration] parameters, list[Expression] exceptions, Statement impl) => \method(modifiers, typeParameters, \return, \id("method"), parameters, exceptions, impl)
     case  \method(list[Modifier] modifiers, list[Declaration] typeParameters, Type \return, Expression name, list[Declaration] parameters, list[Expression] exceptions) => \method(modifiers, typeParameters, \return, \id("method"), parameters, exceptions)
     case  \constructor(list[Modifier] modifiers, Expression name, list[Declaration] parameters, list[Expression] exceptions, Statement impl) => \constructor(modifiers, \id("constructor"), parameters, exceptions, impl)
    //case   | \variables(list[Modifier] modifiers, Type \type, list[Declaration] \fragments) // maybe?
     case  \variable(Expression name, list[Declaration] dimensionTypes) => \variable(\id("var"), dimensionTypes)
     // might need to edit the initializer below
     case  \variable(Expression name, list[Declaration] dimensionTypes, Expression \initializer) => \variable(\id("var"), dimensionTypes, initializer)
     case  \typeParameter(Expression name, list[Type] extendsList) => \typeParameter(\id("typeParam"), extendsList)
     case  \annotationType(list[Modifier] modifiers, Expression name, list[Declaration] body) => \annotationType(modifiers, \id("annoType"), body)
     case  \annotationTypeMember(list[Modifier] modifiers, Type \type, Expression name) => \annotationTypeMember(modifiers, \type, \id("annoTypeMember"))
     case  \annotationTypeMember(list[Modifier] modifiers, Type \type, Expression name, Expression defaultBlock) => \annotationTypeMember(modifiers, \type, \id("annoTypeMember"), defaultBlock)
     case  \parameter(list[Modifier] modifiers, Type \type, Expression name, list[Declaration] dimensions) => \parameter(modifiers,\type, \id("parameter"), dimensions)
     case  \vararg(list[Modifier] modifiers, Type \type, Expression name) => \vararg(modifiers,\type,\id("vararg"))

     //Statements
     case \label(str identifier, Statement body) => \label("label", body)
    //  | \throw(Expression expression) // maybe

     //Type (don't think i need to do this one)
     //Modifier (might not need to do this one but it could be helpful)
    }
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