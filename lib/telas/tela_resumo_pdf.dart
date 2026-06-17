import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/gemini_service.dart';
import '../models/documento.dart';
import '../services/documento_service.dart';

class TelaResumoPdf extends StatefulWidget {
  const TelaResumoPdf({super.key});

  @override
  State<TelaResumoPdf> createState() => _TelaResumoPdfState();
}

class _TelaResumoPdfState extends State<TelaResumoPdf> {
  final GeminiService _geminiService = GeminiService();
  final DocumentoService _documentoService = DocumentoService();
  
  String? _pdfName;
  String? _summaryText;
  bool _isLoading = false;
  String? _errorMessage;
  final String _loadingMessage = 'A IA está lendo o PDF e\ngerando o resumo...';
  
  List<Documento> _historico = [];

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final docs = await _documentoService.getDocumentos();
    setState(() {
      _historico = docs.where((d) => d.tipo == 'resumo').toList();
    });
  }

  Future<void> _pickAndSummarizePdf() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _pdfName = result.files.single.name;
          _isLoading = true;
          _summaryText = null;
          _errorMessage = null;
        });

        // Salvar arquivo localmente
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
        final savedFile = File(path.join(appDir.path, fileName));
        await savedFile.writeAsBytes(result.files.single.bytes!);

        final summary = await _geminiService.summarizePdf(
          result.files.single.bytes!,
        );
        
        final novoDoc = Documento(
          titulo: _pdfName?.replaceAll('.pdf', '') ?? 'Assunto do PDF',
          tipo: 'resumo',
          caminho: savedFile.path,
          nomeArquivo: _pdfName!,
          resumo: summary,
          dataCriacao: DateTime.now().toIso8601String(),
        );
        await _documentoService.insertDocumento(novoDoc);
        await _carregarHistorico();

        setState(() {
          _summaryText = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _abrirHistorico(Documento doc) {
    if (doc.tipo == 'resumo' && doc.resumo != null) {
      setState(() {
        _pdfName = doc.nomeArquivo;
        _summaryText = doc.resumo;
        _errorMessage = null;
      });
    }
  }

  Future<void> _excluirHistorico(Documento doc) async {
    if (doc.id != null) {
      await _documentoService.deleteDocumento(doc.id!);
      
      try {
        final file = File(doc.caminho);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Erro ao deletar arquivo: $e');
      }

      await _carregarHistorico();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('IA: Resumo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_summaryText != null || _pdfName != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _summaryText = null;
                  _pdfName = null;
                });
              },
            )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndSummarizePdf,
                icon: const Icon(Icons.text_snippet_rounded),
                label: const Text(
                  'Gerar Resumo a partir de PDF',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0xFF8B5CF6).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_pdfName != null && _summaryText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pdfName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF8B5CF6),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Ops, ocorreu um erro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade600, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (_summaryText != null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Markdown(
          data: _summaryText!,
          physics: const BouncingScrollPhysics(),
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            p: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF334155)),
            listBullet: const TextStyle(fontSize: 16, color: Color(0xFF8B5CF6)),
            blockquote: const TextStyle(
              fontSize: 16, 
              fontStyle: FontStyle.italic, 
              color: Color(0xFF64748B),
            ),
            blockquoteDecoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: Color(0xFF8B5CF6), width: 4)),
            ),
          ),
        ),
      );
    } else {
      return _buildHistorico();
    }
  }

  Widget _buildHistorico() {
    if (_historico.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.text_snippet_rounded,
              size: 64,
              color: Color(0xFFE2E8F0),
            ),
            SizedBox(height: 16),
            Text(
              'Gere um resumo usando um PDF para\nver seu histórico aqui.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumos Salvos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _historico.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final doc = _historico[index];
              return Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.1),
                    child: const Icon(
                      Icons.text_snippet_rounded,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  title: Text(
                    doc.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text(
                    'Resumo Salvo',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _excluirHistorico(doc),
                  ),
                  onTap: () => _abrirHistorico(doc),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
