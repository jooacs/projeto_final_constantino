class Questao {
  String pergunta;
  List<String> opcoes;
  int indiceRespostaCorreta;

  Questao({
    required this.pergunta,
    required this.opcoes,
    required this.indiceRespostaCorreta,
  });

  factory Questao.fromJson(Map<String, dynamic> json) {
    return Questao(
      pergunta: json['pergunta'],
      opcoes: List<String>.from(json['opcoes']),
      indiceRespostaCorreta: json['indiceRespostaCorreta'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pergunta': pergunta,
      'opcoes': opcoes,
      'indiceRespostaCorreta': indiceRespostaCorreta,
    };
  }
}
