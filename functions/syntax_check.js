
try {
    require('./index.js');
    console.log("Syntax check passed: index.js loaded successfully.");
} catch (e) {
    console.error("Syntax Error or Load Error:");
    console.error(e);
}
