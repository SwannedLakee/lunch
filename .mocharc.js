module.exports = {
  extension: ["ts"],
  require: ["./test/setup"],
  exit: true,
  file: "./test/mocha-setup",
  timeout: 4000,
};
