var fsio = require('fs');
var path = require('path');
var static = require('node-static');

function showUsageAndExit() {
    console.log("Invalid option or directory.\n\n");
    console.log("Optional Parameters:");
    console.log("\t-p <port-number>\t\tThe port number to use");
    console.log("\t<target-directory>\t\tDefaults to current directory");
    process.exit();
}

var dir = "./";
var port = 8080;

var args = process.argv.splice(2);
if (args.length > 0 && args.length < 4) {
    for (var i = 0; i < args.length; i++) {
        try {
            switch (args[i]) {
            case "-p":
                port = parseInt(args[++i]);
                break;
            default:
                dir = args[i];
                break;
            }
        } catch(e) {
            showUsageAndExit();
        }
    }
}

dir = path.resolve(dir);

var stats = fsio.lstatSync(dir);
if (!stats.isDirectory) {
    showUsageAndExit();
}

//
// Create a node-static server instance to serve the './public' folder
//
var srv = new(static.Server)(dir);

require('http').createServer(function(request, response) {
    request.addListener("end",
    function() {
        srv.serve(request, response);
        // Serve files!
    });
}).listen(port);

console.log("PID " + process.pid + " started on port " + port.toString() + " in '" + dir + "'");