/// Fora do navegador não há iframe nem `<video>`: o [InlineVideo] usa o
/// player nativo do YouTube ou abre o arquivo por fora antes de chegar aqui.
String videoViewType(String url, {String? youtubeId}) =>
    throw UnsupportedError('Player embutido em HTML só no navegador');
