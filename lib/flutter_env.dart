library flutter_env;

import 'dart:io';
import 'dart:core';
import 'package:path/path.dart' as path;

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
    if (content.isNotEmpty) {
      content = content.map((item) {
        item = item.replaceAll("=", ' = "');
        item = ' static String $item";';
        return item;
      });
    }

    final properties = content.join('\n');
    this.code = "class ENV {\n$properties\n }";
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

class DotENV {
  DotENV(commandLine) {
    this.create(commandLine: commandLine);
  }
  create({commandLine: String}) async {
    final parsed = this.parse(commandLine: commandLine);
    final paths = this.getPath(parsed);

    final content = await this.getENVContent(path:paths['origin']);

    final expanded = this.expand(content, false);

    final codes = _GenCodeOfDart(expanded).code;

    this.write(paths['generated'], codes);
  }

  parse({commandLine: String}) {
    Map result = {};
    for (var i = 0; i < commandLine.length; i++) {
      if (i % 2 == 0 && i + 1 < commandLine.length) {
        var key = commandLine[i];
        var value = commandLine[i + 1];
        if (key.indexOf('--') == 0 || key.indexOf('-') == 0) {
          if (key.indexOf('--') == 0) {
            key = key.substring(2);
          } else if (key.indexOf('-') == 0) {
            key = key.substring(1);
          }
          if (value == null) {
            value = true;
          }
          result[key] = value;
        }
      }
    }
    return result;
  }

  getPath(argv) {
    const DEFAULT_ENVFILE = ".env";
    const DEFAULT_DIRNAME = "./";
    const NOT_GENERATE_OBJECTIVE_C_FILE = true;
    const NOT_GENERATE_GRADLE_FILE = true;
    const DEFAULT_PLATFORM = "flutter";
    final platform =
    argv['platform'] == null ? DEFAULT_PLATFORM : argv['platform'];
    final envfile = argv['envfile'] == null ? DEFAULT_ENVFILE : argv["envfile"];
    final dirname = argv['dirname'] == null ? DEFAULT_DIRNAME : argv['dirname'];
    final generateObjcFile = argv["generate-objc"] == null
        ? NOT_GENERATE_OBJECTIVE_C_FILE
        : argv["generate-objc"];
    final generateGradleFile = argv["generate-gradle"] == null
        ? NOT_GENERATE_GRADLE_FILE
        : argv["generate-objc"];

    String envfileRelativePath = "./";
    switch (platform) {
      case "android":
        envfileRelativePath = "../../";
        break;
      case "ios":
        envfileRelativePath = "../";
        break;
      default:
        break;
    }
    String envfilePath = path.join(dirname, envfileRelativePath, envfile);
    envfilePath = path.normalize(envfilePath);
    String dartEnvFilePath =
    path.join(dirname, envfileRelativePath, 'lib/env.dart');
    dartEnvFilePath = path.normalize(dartEnvFilePath);

    return {
      "origin": envfilePath,
      "generated": dartEnvFilePath,
    };
  }

  getENVContent({path:String}) async {
    String content;
    try {
      content = await File(path).readAsString();
    } catch (e) {
      print("**************************");
      print("*** Missing .env file ****");
      print("**************************");
    }
    return content;
  }

  write(filename, content) async {
    try {
      await File(filename).writeAsString(content, mode: FileMode.write);
      print('file: $filename written');
    } catch (error) {
      print('oops,file written failed');
      print(error);
    }
  }

  expand(content, shouldExpend) {
    List<String> list = content
        .split("\n")
        .where((item) => item != null && item != '')
        .toList();
    if (shouldExpend == true && list.isNotEmpty) {
      List<List> expanded = list.map((item) => item.split("=")).toList();
      return expanded;
    } else {
      return list;
    }
  }
}
