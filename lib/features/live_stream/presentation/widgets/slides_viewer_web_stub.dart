/// Fora do navegador não há iframe: o [SlidesViewer] mostra "Abrir slides"
/// antes de chegar aqui.
String slidesViewType(String url) =>
    throw UnsupportedError('Slides embutidos em HTML só no navegador');
