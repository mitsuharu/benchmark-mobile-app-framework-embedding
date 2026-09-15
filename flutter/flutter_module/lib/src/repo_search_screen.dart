import 'dart:async';

import 'package:flutter/material.dart';

import 'github_client.dart';
import 'host_channel.dart';

const _primary = Color(0xFF111827);
const _secondary = Color(0xFFE5E7EB);
const _subtitle = Color(0xFF6B7280);
const _description = Color(0xFF4B5563);
const _placeholder = Color(0xFF9CA3AF);
const _errorColor = Color(0xFFB91C1C);

/// The screen every implementation embeds: searches GitHub for the keyword the
/// host app handed over and lists the repositories.
class RepoSearchScreen extends StatefulWidget {
  const RepoSearchScreen({
    super.key,
    required this.initialKeyword,
    required this.client,
    required this.host,
    required this.keywordChanges,
  });

  /// Handed over by the host app when it opened the screen.
  final String initialKeyword;
  final GitHubClient client;
  final HostChannel host;

  /// Keywords the host app sends while the screen is open.
  final Stream<String> keywordChanges;

  @override
  State<RepoSearchScreen> createState() => _RepoSearchScreenState();
}

class _RepoSearchScreenState extends State<RepoSearchScreen> {
  late String _keyword = widget.initialKeyword;
  List<Repository> _repositories = const [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<String>? _keywordSubscription;

  @override
  void initState() {
    super.initState();
    widget.host.markAfterFrame(BenchMarker.embedFirstFrame);
    // The keyword passed in only arrives while the screen is being created,
    // so replacing it on an open screen comes over the channel.
    _keywordSubscription = widget.keywordChanges.listen((next) {
      setState(() {
        _keyword = next;
        _repositories = const [];
        _error = null;
      });
      widget.host.markAfterFrame(BenchMarker.keywordApplied);
    });
  }

  @override
  void dispose() {
    _keywordSubscription?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    widget.host.mark(BenchMarker.searchTapped);
    final keyword = _keyword;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.client.searchRepositories(keyword);
      if (!mounted) return;
      setState(() => _repositories = results);
      if (results.isNotEmpty) {
        widget.host.markAfterFrame(BenchMarker.searchRendered);
      }
      // Hand the results back to the native host app.
      widget.host.notifySearchSucceeded(keyword, results);
    } catch (e) {
      final message = e is GitHubException ? e.message : e.toString();
      if (!mounted) return;
      setState(() {
        _repositories = const [];
        _error = message;
      });
      widget.host.notifySearchFailed(keyword, message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GitHub Repositories',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'keyword: $_keyword',
                    style: const TextStyle(fontSize: 14, color: _subtitle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: _isLoading ? '検索中...' : 'リポジトリを検索',
                      onPressed: _isLoading ? null : _search,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'ネイティブに戻る',
                    secondary: true,
                    onPressed: widget.host.close,
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: _errorColor),
                ),
              ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _repositories.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_repositories.isEmpty) {
      return _error == null
          ? const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Text(
                'ボタンを押すと検索結果が表示されます。',
                textAlign: TextAlign.center,
                style: TextStyle(color: _placeholder),
              ),
            )
          : const SizedBox.shrink();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: _repositories.length,
      itemBuilder: (context, index) =>
          _RepositoryRow(repository: _repositories[index]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? _secondary : _primary,
        foregroundColor: secondary ? _primary : Colors.white,
        disabledBackgroundColor: _primary.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RepositoryRow extends StatelessWidget {
  const _RepositoryRow({required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) {
    final language = repository.language;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _secondary, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              repository.fullName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (repository.description != null) ...[
              const SizedBox(height: 4),
              Text(
                repository.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: _description),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '★ ${groupThousands(repository.stars)}'
              '${language != null ? ' · $language' : ''}',
              style: const TextStyle(fontSize: 12, color: _subtitle),
            ),
          ],
        ),
      ),
    );
  }
}

/// 51842 → "51,842", as the other implementations format star counts.
String groupThousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
