// double findClosestPoint(double target, double p1, double p2, double p3) {
//   // Вычисляем абсолютное расстояние до каждой точки
//   double d1 = (target - p1).abs();
//   double d2 = (target - p2).abs();
//   double d3 = (target - p3).abs();

//   // Находим минимальное расстояние
//   double minDistance = d1 < d2 ? (d1 < d3 ? d1 : d3) : (d2 < d3 ? d2 : d3);

//   // Возвращаем соответствующую точку
//   if (minDistance == d1) return p1;
//   if (minDistance == d2) return p2;
//   return p3;
// }