library flutter_env;


import 'dart:io';
import 'dart:core';
final String iosDir = "./ios/Runner";
final String androidDir = "./android/app";
final String dartDir = "./lib";
parseArguments({List argv}) {
  Map<String, String> result = {"filename": ""};
  for (var i = 0; i < argv.length; i++) {
    var items = argv[i].split('=');
    if (items.first == 'file') {
      result.addAll({"filename": "${items.last}"});
    }
  }
  return result;
}
abstract class _CodeGen {
  String output = '';
  _CodeGen(content) {
    this.generate(content);
  }
  generate(content) {}
}
class _GenCodeOfDart extends _CodeGen {
  String code = "";
  _GenCodeOfDart(content) : super(content);
  generate(content) {
    content = content.map((item) {
      item = item.replaceAll("=", ' = "');
      item = ' static String $item";';
      return item;
    });
    final properties = content.join('\n');
    this.code = "class EnvOfDart {\n$properties\n }";
  }
}
class _GenCodeOfObjc extends _CodeGen {
  String code = "";
  _GenCodeOfObjc(content) : super(content);
  @override
  generate(content) {
    List list = [];
    for (var i = 0; i < content.length; i++) {
      var item = content[i];
      list.add('@"${item.first}":@"${item.last}"');
    }

    String objcContent = list.join(',\n');
    this.code = "#define DotEnv @{\n$objcContent\n};";
  }
}
class _GenCodeOfGradle extends _CodeGen {
  String code = "";
  _GenCodeOfGradle(content) : super(content);
  template(content) {
    String android = "android{  \n";
    android += "  defaultConfig{ \n";
    android += "$content \n";
    android += "}";
    this.code = android;
  }

  @override
  generate(content) {
    List list = [];
    for (var i = 0; i < content.length; i++) {
      var item = content[i];
      list.add(
          '      buildConfigField "String","${item.first}","${item.last}"');
      list.add('      resValue "String",${item.first},"${item.last}"');
    }
    this.template(list.join("\n"));
  }
}
class DovEnv {
  String _objcFile = "$iosDir/dotEnv.m";
  String _dartFile = "$dartDir/dot_env.dart";
  String _gradleFile = "$androidDir/dotenv.gradle";
  CodeGenerator(argvs) {
    this._initialize(argvs);
  }
  _initialize(argvs) async {
    String envfile = await this._getENVFilename(argvs);

    if(envfile !=null){
      await this._createDirectory();
      await this._generator(envFile: envfile);
    }
  }
  _createDirectory() async {

    if( Directory(iosDir).existsSync() == false){
      await Directory(iosDir).create(recursive: true);
    }

    if( Directory(dartDir).existsSync() == false){
      await Directory(dartDir).create(recursive: true);
    }

    if( Directory(androidDir).existsSync() == false){
      await Directory(androidDir).create(recursive: true);
    }

  }

  _getENVFilename(argvs) async {
    Map parsed = parseArguments(argv: argvs);
    String envFile = './.env';
    if (parsed.isNotEmpty) {
      envFile = parsed['filename'];
    }
    try {
      await File(envFile).open();
    } catch (e) {
      print("**************************");
      print("Missing $envFile file");
      print("**************************");
    }

    return envFile;
  }

  _writeFile(filename, content) async {
    try {
      await File(filename).writeAsString(content, mode: FileMode.write);
      print('file: $filename written');
    } catch (error) {
      print('oops');
      print(error);
    }
  }

  _generator({envFile: String}) async {
    var content = await File(envFile).readAsString();
    this._dart(content: this._expand(content, false));
    this._objc(content: this._expand(content, true));
    this._gradle(content: this._expand(content, true));
  }

  _expand(content, shouldExpend) {
    List<String> list = content.split("\n").toList();
    if (shouldExpend == true) {
      List<List> expanded = list.map((item) => item.split("=")).toList();
      return expanded;
    } else {
      return list;
    }
  }
  _dart({content: List}) =>
      this._writeFile(this._dartFile, _GenCodeOfDart(content).code);
  _objc({content}) =>
      this._writeFile(this._objcFile, _GenCodeOfObjc(content).code);
  _gradle({content: List}) =>
      this._writeFile(this._gradleFile, _GenCodeOfGradle(content).code);
}
