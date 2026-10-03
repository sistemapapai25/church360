/// Fora do navegador não há `<video>`; o [InlineVideo] abre o arquivo por
/// fora antes de chegar aqui.
String videoViewType(String url) =>
    throw UnsupportedError('Vídeo de arquivo embutido só no navegador');
