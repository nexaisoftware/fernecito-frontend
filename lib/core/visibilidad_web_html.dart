import 'dart:html' as html;

void escucharVisibilidadWeb(void Function() alMostrarse) {
  html.document.onVisibilityChange.listen((_) {
    if (html.document.visibilityState == 'visible') {
      alMostrarse();
    }
  });
}
