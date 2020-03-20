#!./node
const alfy = require('alfy')
const translate = require('google-translate-api');
const languages = require('./languages');

var source = process.argv[2]
var target = process.argv[3]
var query = process.argv[4]

items = []

translate(query, { from: source, to: target, raw: true }).then(res => {
  var rawStr = res.raw.replace(/,,/g, ',null,').replace(/,,/g, ',null,').replace(/\[,/g, '[null,');
  var raw = JSON.parse(rawStr);
  from_lang = languages[(res.from && res.from.language.iso) || source]
  to_lang = languages[(res.to && res.to.language.iso) || target]
  language_pair = `(${from_lang} -> ${to_lang})`

  if (res.from.text.autoCorrected || res.from.text.didYouMean) {
    var autoCorrected = res.from.text.value.replace(/\<[^\<\>]+\>/g, '');
    autoCorrected = autoCorrected.replace(/\[/, '').replace(/\]/, '');

    items.push({ title: autoCorrected, subtitle: `Did you mean this? ${language_pair}`, autocomplete: autoCorrected });
  }

  if (res.text) {
    const text = res.text.replace(/null$/, '');
    items.push({ title: text, subtitle: language_pair, arg: text });
  }

  if (raw && raw[1]) {
    raw[1].forEach((group) => {
      var type = group[0];

      group[2].forEach((wordData) => {
        var word = wordData[0];
        var translations = wordData[1];
        var frequency = wordData[3];
        items.push({ title: word, subtitle: `(${type}) ${translations.join(', ')}`, arg: word });
      });
    });
  }

  alfy.output(items);
});
