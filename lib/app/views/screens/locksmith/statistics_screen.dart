import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_test/app/controllers/job_controller.dart';
import 'package:flutter_application_test/data/models/job_model.dart';
import 'package:intl/intl.dart';

import 'completed_jobs_list_screen.dart';

// Enum is now imported from job_controller.dart, so we remove the definition from here.

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final JobController _jobController = JobController();
  late Future<Map<String, dynamic>> _statisticsFuture;
  StatisticsTimeFilter _selectedFilter = StatisticsTimeFilter.week; // Default to week
  DateTime _targetDate = DateTime.now(); // Date to determine the week/month

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    _statisticsFuture = _jobController.getRepairerStatistics(
      _selectedFilter,
      targetDate: _targetDate,
    );
  }

  void _onFilterChanged(StatisticsTimeFilter filter) {
    setState(() {
      _selectedFilter = filter;
      _targetDate = DateTime.now(); // Reset to current week/month when filter changes
      _loadStatistics();
    });
  }

  void _changeMonth(int months) {
    setState(() {
      _targetDate = DateTime(_targetDate.year, _targetDate.month + months, 1);
      _loadStatistics();
    });
  }

  void _changeWeek(int weeks) {
    setState(() {
      _targetDate = _targetDate.add(Duration(days: 7 * weeks));
      _loadStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống Kê Thu Nhập'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statisticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có dữ liệu để hiển thị.'));
          }

          final stats = snapshot.data!;
          return _buildStatisticsView(stats);
        },
      ),
    );
  }

  Widget _buildStatisticsView(Map<String, dynamic> stats) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _loadStatistics();
        });
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFilterButtons(),
          if (_selectedFilter == StatisticsTimeFilter.week) _buildWeekNavigator(),
          if (_selectedFilter == StatisticsTimeFilter.month) _buildMonthNavigator(),
          const SizedBox(height: 24),
          _buildSummaryCards(stats),
          const SizedBox(height: 24),
          _buildChartCard(stats),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    String monthDisplay = 'Tháng ${DateFormat('MM/yyyy').format(_targetDate)}';

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(monthDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator() {
    DateTime startOfWeek = _targetDate.subtract(Duration(days: _targetDate.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
    String weekDisplay =
        '${DateFormat('dd/MM').format(startOfWeek)} - ${DateFormat('dd/MM/yyyy').format(endOfWeek)}';

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-1),
          ),
          Text(weekDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SegmentedButton<StatisticsTimeFilter>(
      segments: const <ButtonSegment<StatisticsTimeFilter>>[
        ButtonSegment(value: StatisticsTimeFilter.week, label: Text('Tuần')),
        ButtonSegment(value: StatisticsTimeFilter.month, label: Text('Tháng')),
        ButtonSegment(value: StatisticsTimeFilter.all, label: Text('Tất cả')),
      ],
      selected: {_selectedFilter},
      onSelectionChanged: (Set<StatisticsTimeFilter> newSelection) {
        _onFilterChanged(newSelection.first);
      },
      style: SegmentedButton.styleFrom(
        foregroundColor: Colors.grey,
        selectedForegroundColor: Colors.white,
        backgroundColor: Colors.grey.shade200,
        selectedBackgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    final numberFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard('Tổng Doanh Thu', numberFormat.format(stats['totalRevenue']), Icons.attach_money),
        GestureDetector(
          onTap: () {
            final List<JobModel> jobs = List.from(stats['completedJobsList']);
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => CompletedJobsListScreen(completedJobs: jobs),
            ));
          },
          child: _buildSummaryCard('Việc Hoàn Thành', '${stats['completedJobs']}', Icons.check_circle, isClickable: true),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, {bool isClickable = false}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (isClickable) const SizedBox(width: 8),
                  if (isClickable) Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(Map<String, dynamic> stats) {
    final List<Map<String, dynamic>> chartData = List.from(stats['chartData']);
    
    // Prepare data for Bar Chart
    final barGroups = chartData.asMap().entries.map((entry) {
      final index = entry.key;
      final revenue = (entry.value['revenue'] as double);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: revenue,
            color: Theme.of(context).primaryColor,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biểu Đồ Doanh Thu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            if (barGroups.isEmpty || chartData.every((e) => e['revenue'] == 0.0))
              Container(
                height: 200,
                alignment: Alignment.center,
                child: const Text("Không có dữ liệu cho biểu đồ"),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: 200,
                  width: chartData.length * 40.0, // Provide ample space for each bar
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final day = DateTime.parse(chartData[group.x.toInt()]['day']);
                            final formattedDate = DateFormat('dd/MM').format(day);
                            final formattedRevenue = NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(rod.toY);
                            return BarTooltipItem(
                              '$formattedDate\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: formattedRevenue,
                                  style: TextStyle(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.w500),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: _selectedFilter == StatisticsTimeFilter.month ? 5 : 2, // Adjust interval for scrollable view
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < chartData.length) {
                                final date = DateTime.parse(chartData[index]['day']);
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 10,
                                  child: Text(DateFormat('d/M').format(date)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      barGroups: barGroups,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 