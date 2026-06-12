String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String getWeekDayName(int index){
  return index == DateTime.monday
                ? "MON"
                : index == DateTime.tuesday
                    ? "TUE"
                    : index == DateTime.wednesday
                        ? "WED"
                        : index == DateTime.thursday
                            ? "THU"
                            : index == DateTime.friday
                                ? "FRI"
                                : index == DateTime.saturday
                                    ? "SAT"
                                    : "SUN";
}