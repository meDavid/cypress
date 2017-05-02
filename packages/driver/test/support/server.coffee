_         = require("lodash")
express   = require("express")
http      = require("http")
path      = require("path")
fs        = require("fs")
hbs       = require("hbs")
glob      = require("glob")
coffee    = require("coffee-script")
str       = require("string-to-stream")
Promise   = require("bluebird")
xhrs      = require("../../../app/lib/controllers/xhrs")
Runner    = require("./server/runner")

[3500, 3501].forEach (port) ->

  app       = express()
  server    = http.Server(app)

  app.set 'port', port

  app.set "view engine", "html"
  app.engine "html", hbs.__express

  app.use require("cors")()
  app.use require("compression")()
  app.use require("morgan")(format: "dev")
  app.use require("body-parser")()
  app.use require("method-override")()

  if port is 3500
    new Runner({ port }).start(server)

  removeExtension = (str) ->
    str.split(".").slice(0, -1).join(".")

  getSpecPath = (pathName) ->
    if /all_specs/.test(pathName) then getAllSpecs(false) else [pathName.replace(/^\//, "")]

  getAllSpecs = (allSpecs = true) ->
    specs = glob.sync "../!(support)/**/*.coffee", cwd: __dirname
    specs.unshift "client/all_specs.coffee" if allSpecs
    _.map specs, (spec) ->
      ## replace client/whatevs.coffee -> specs/whatevs.coffee
      spec = spec.split("/")
      spec.splice(0, 1, "specs")

      ## strip off the extension
      removeExtension spec.join("/")

  getSpec = (spec) ->
    spec = removeExtension(spec) + ".coffee"
    file = fs.readFileSync path.join(__dirname, "..", spec), "utf8"
    coffee.compile(file)

  sendJs = (res, pathOrContents, isContents = false) ->
    res.set({
      "Cache-Control": "no-cache, no-store, must-revalidate"
      "Pragma": "no-cache"
      "Expires": "0"
    })
    res.type("js")
    if isContents
      res.send(pathOrContents)
    else
      res.sendFile(pathOrContents)

  app.get "/specs/*", (req, res) ->
    spec = req.params[0]

    if /\.js$/.test(spec)
      sendJs(res, getSpec(spec), true)
    else
      res.render(path.join(__dirname, "..", "support", "views", "spec.html"), {
        specs: getSpecPath(req.path)
      })

  app.get "/timeout", (req, res) ->
    setTimeout ->
      res.send "<html></html>"
    , req.query.ms

  app.get "/node_modules/*", (req, res) ->
    res.sendFile path.join("node_modules", req.params[0]),
      root: path.join(__dirname, "../..")

  app.get "/dist-test/*", (req, res) ->
    filePath = path.join(__dirname, "../../dist-test", req.params[0])
    if /\.js$/.test(filePath)
      sendJs(res, filePath)
    else
      res.sendFile(filePath)

  app.get "/fixtures/*", (req, res) ->
    res.sendFile "fixtures/#{req.params[0]}",
      root: __dirname

  app.get "/xml", (req, res) ->
    res.type("xml").send("<foo>bar</foo>")

  app.get "/buffer", (req, res) ->
    fs.readFile path.join(__dirname, "fixtures", "sample.pdf"), (err, bytes) ->
      res.type("pdf")
      res.send(bytes)

  app.all "/__cypress/xhrs/*", (req, res) ->
    xhrs.handle(req, res)

  app.get "/", (req, res) ->
    res.render path.join(__dirname, "views", "index.html"), {
      specs: getAllSpecs()
    }

  app.get "*", (req, res) ->
    filePath = req.params[0].replace(/\/+$/, "")
    if /\.js$/.test filePath
      sendJs(res, path.join(__dirname, filePath))
    else
      res.sendFile(filePath, { root: __dirname })

  ## errorhandler
  app.use require("errorhandler")()

  server.listen app.get("port"), ->
    console.log 'Express server listening on port ' + app.get('port')