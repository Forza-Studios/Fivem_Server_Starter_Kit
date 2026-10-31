# Banco de som — v4.6

174 ficheiros mono PCM16 a 48 kHz, gerados por `node tools/build-bank.js` a partir de `tools/source/`. Os 134 ficheiros da v4.5 saem iguais byte a byte; a v4.6 acrescenta 40.

| Família | Ficheiros | Uso |
| --- | --- | --- |
| snap, crackle | 24 cada | pops das mudanças, desaceleração e limitador |
| burble | 16 | estalos graves e redondos: caudas e desacelerações lentas |
| bang | 24 | bangs |
| boom | 16 | os estalos mais fortes: disparos completos, nos níveis 3 e 4 |
| als_hit | 16 | estouros do anti-lag e do two-step (opcionais; só carregados com `Config.AntiLag.bangs` ou `twoStep` ligados) |
| als_bang | 10 | acentos graves do anti-lag (idem) |
| turbo_flutter, turbo_bov | 10 cada | flutter do compressor e válvula de descarga, incluindo a descarga nas subidas de mudança. Os dois primeiros de cada são síntese; os oito seguintes são ar comprimido real a ser libertado |
| whoosh | 8 | o som da própria chama: gás a inflamar-se e a sair do tubo, por baixo dos booms e dos bangs maiores |
| hiss | 6 | chuva a virar vapor num escape quente |
| tick | 10 | o escape a estalar enquanto arrefece, com o motor desligado |

Cada pop e cada estouro parte de gravações reais (`tools/source/real_*.wav`: backfires, petardos e disparos de arma; e as gravações da v3), afinadas e cortadas por família. A síntese acrescenta só o ataque, uma explosão de ruído que escurece, o crepitar e o grave dos bangs; não há ressonâncias de nota fixa. O assobio contínuo do turbo é gerado em tempo real por audio.js e não tem ficheiro.

As famílias da v4.6 (whoosh, hiss, tick e os turbo 03–10) são gravações reais de chamas, vapor, ar comprimido e de um motor a arrefecer. De cada gravação aproveita-se a textura: o nível é aplanado e a forma (ataque, duração, queda) é a que o gerador lhe dá, por isso todas as tomadas de uma família têm o mesmo comportamento e timbres diferentes.

As gravações aprovadas numa versão mantêm a sua seed: ao reconstruir o banco saem iguais byte a byte, e as novas entram ao volume da família a que se juntam. Ao tocar, cada estalo leva ainda camadas de outras gravações, equalização própria e afinação (ver o README do recurso).

`bank.json` regista seed, gravações usadas e SHA-256 de cada ficheiro. `LICENSES.md` tem as atribuições das gravações (CC0 e CC BY 4.0), que continuam a aplicar-se.
