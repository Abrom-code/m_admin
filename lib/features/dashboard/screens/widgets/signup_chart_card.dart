import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/line_chart_painter.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';

class SignupChartCard extends StatelessWidget {
  const SignupChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminSection(
      title: 'Signups over time',
      trailing: Obx(
        () => SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7d')),
            ButtonSegment(value: 30, label: Text('30d')),
            ButtonSegment(value: 90, label: Text('90d')),
          ],
          selected: {controller.rangeDays.value},
          onSelectionChanged: (set) => controller.rangeDays.value = set.first,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      child: Obx(() {
        final series = controller.signupSeries;
        if (series.length < 2) {
          return const SizedBox(
            height: 130,
            child: Center(
              child: Text(
                'No signup data yet',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final points = <LinePoint>[
          for (int i = 0; i < series.length; i++)
            LinePoint(i / (series.length - 1), series[i].value),
        ];

        return AdminLineChart(points: points, color: AppColors.info);
      }),
    );
  }
}
